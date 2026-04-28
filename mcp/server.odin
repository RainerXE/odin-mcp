// server.odin — MCP server dispatch loop.
// Call server_init, register tools/resources/prompts, then server_run (blocks on stdin).
package mcp

import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

BUFIO_SIZE :: 64 * 1024

// server_init prepares s for use.  Call once before registering anything.
server_init :: proc(s: ^MCPServer, name: string, version: string) {
	s.name      = name
	s.version   = version
	s.tools     = make([dynamic]Tool)
	s.resources = make([dynamic]Resource_Def)
	s.prompts   = make([dynamic]Prompt_Def)
}

// server_set_context stores a rawptr that is forwarded to every Context_*_Handler.
server_set_context :: proc(s: ^MCPServer, ctx: rawptr) {
	s.user_context = ctx
}

// server_register_tool appends one tool to the dispatch table.
server_register_tool :: proc(s: ^MCPServer, tool: Tool) {
	append(&s.tools, tool)
}

// server_register_resource appends one resource to the dispatch table.
server_register_resource :: proc(s: ^MCPServer, res: Resource_Def) {
	append(&s.resources, res)
}

// server_register_prompt appends one prompt to the dispatch table.
server_register_prompt :: proc(s: ^MCPServer, p: Prompt_Def) {
	append(&s.prompts, p)
}

// server_run enters the read/dispatch/write loop.
// Blocks until stdin EOF or unrecoverable I/O error.
server_run :: proc(s: ^MCPServer) {
	buf := make([]u8, BUFIO_SIZE)
	defer delete(buf)

	reader: bufio.Reader
	bufio.reader_init_with_buf(&reader, os.to_reader(os.stdin), buf)
	defer bufio.reader_destroy(&reader)

	for {
		defer free_all(context.temp_allocator)

		raw, ok := read_message(&reader, context.temp_allocator)
		if !ok {
			break
		}

		val, parse_err := json.parse(raw, allocator = context.temp_allocator)
		if parse_err != nil {
			write_string_message(build_error_response({}, ERR_PARSE_ERROR, "JSON parse error", context.temp_allocator))
			continue
		}

		req, extract_ok := _extract_request(val)
		if !extract_ok {
			write_string_message(build_error_response({}, ERR_INVALID_REQUEST, "invalid JSON-RPC request", context.temp_allocator))
			continue
		}

		resp, has_resp := _dispatch(s, req)
		if has_resp {
			write_string_message(resp)
		}
	}
}

// ── Internal helpers ──────────────────────────────────────────────────────────

@(private="file")
_extract_request :: proc(val: json.Value) -> (req: MCPRequest, ok: bool) {
	obj, is_obj := val.(json.Object)
	if !is_obj { return {}, false }

	method_val, has_method := obj["method"]
	if !has_method { return {}, false }
	method_str, is_str := method_val.(json.String)
	if !is_str { return {}, false }

	req.method = string(method_str)
	req.params  = obj["params"] if "params" in obj else json.Null{}

	if id_val, has_id := obj["id"]; has_id {
		switch v in id_val {
		case json.Integer: req.id = i64(v)
		case json.Float:   req.id = i64(v)
		case json.String:  req.id = string(v)
		case json.Null, json.Boolean, json.Array, json.Object:
		}
	}

	return req, true
}

@(private="file")
_dispatch :: proc(s: ^MCPServer, req: MCPRequest) -> (resp: string, has_resp: bool) {
	is_notification := req.id == nil

	switch req.method {
	case "initialize":
		return _handle_initialize(s, req.id), true

	case "initialized":
		return "", false

	case "ping":
		if is_notification { return "", false }
		return build_success_response(req.id, `{}`, context.temp_allocator), true

	case "tools/list":
		if is_notification { return "", false }
		return _handle_tools_list(s, req.id), true

	case "tools/call":
		if is_notification { return "", false }
		return _handle_tools_call(s, req.id, req.params), true

	case "resources/list":
		if is_notification { return "", false }
		return _handle_resources_list(s, req.id), true

	case "resources/read":
		if is_notification { return "", false }
		return _handle_resources_read(s, req.id, req.params), true

	case "prompts/list":
		if is_notification { return "", false }
		return _handle_prompts_list(s, req.id), true

	case "prompts/get":
		if is_notification { return "", false }
		return _handle_prompts_get(s, req.id, req.params), true

	case:
		if is_notification { return "", false }
		return build_error_response(req.id, ERR_METHOD_NOT_FOUND,
			fmt.tprintf("method not found: %s", req.method), context.temp_allocator), true
	}
}

@(private="file")
_handle_initialize :: proc(s: ^MCPServer, id: RPCID) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, `{"protocolVersion":"`)
	strings.write_string(&b, MCP_PROTOCOL_VERSION)
	strings.write_string(&b, `","capabilities":{"tools":{}`)
	if len(s.resources) > 0 {
		strings.write_string(&b, `,"resources":{}`)
	}
	if len(s.prompts) > 0 {
		strings.write_string(&b, `,"prompts":{}`)
	}
	strings.write_string(&b, `},"serverInfo":{"name":`)
	json_escape_string(&b, s.name)
	strings.write_string(&b, `,"version":`)
	json_escape_string(&b, s.version)
	strings.write_string(&b, `}}`)
	return build_success_response(id, strings.to_string(b), context.temp_allocator)
}

@(private="file")
_handle_tools_list :: proc(s: ^MCPServer, id: RPCID) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, `{"tools":[`)
	for tool, i in s.tools {
		if i > 0 { strings.write_byte(&b, ',') }
		strings.write_string(&b, `{"name":`)
		json_escape_string(&b, tool.defn.name)
		strings.write_string(&b, `,"description":`)
		json_escape_string(&b, tool.defn.description)
		strings.write_string(&b, `,"inputSchema":`)
		strings.write_string(&b, tool.defn.input_schema)
		strings.write_byte(&b, '}')
	}
	strings.write_string(&b, `]}`)
	return build_success_response(id, strings.to_string(b), context.temp_allocator)
}

@(private="file")
_handle_tools_call :: proc(s: ^MCPServer, id: RPCID, params: json.Value) -> string {
	params_obj, is_obj := params.(json.Object)
	if !is_obj {
		return build_error_response(id, ERR_INVALID_PARAMS, "params must be an object", context.temp_allocator)
	}

	name_val, has_name := params_obj["name"]
	if !has_name {
		return build_error_response(id, ERR_INVALID_PARAMS, "missing 'name' in params", context.temp_allocator)
	}
	tool_name, is_str := name_val.(json.String)
	if !is_str {
		return build_error_response(id, ERR_INVALID_PARAMS, "'name' must be a string", context.temp_allocator)
	}

	arguments: json.Value = json.Null{}
	if args_val, has_args := params_obj["arguments"]; has_args {
		arguments = args_val
	}

	for tool in s.tools {
		if tool.defn.name != string(tool_name) { continue }

		// Before-hook
		if s.middleware.before_tool != nil {
			hr := s.middleware.before_tool(s.user_context, tool.defn.name)
			if hr == .Abort {
				return build_error_response(id, ERR_INTERNAL_ERROR, "request aborted by middleware", context.temp_allocator)
			}
		}

		// Dispatch to context or simple handler.
		start := time.now()
		result: Tool_Result
		if tool.context_handler != nil {
			result = tool.context_handler(s.user_context, arguments, context.temp_allocator)
		} else {
			result = tool.simple_handler(arguments, context.temp_allocator)
		}
		elapsed_ms := int(time.duration_milliseconds(time.since(start)))

		// After-hook
		if s.middleware.after_tool != nil {
			s.middleware.after_tool(s.user_context, tool.defn.name, &result, elapsed_ms)
		}

		return build_tool_result_from(id, result, context.temp_allocator)
	}

	return build_error_response(id, ERR_METHOD_NOT_FOUND,
		fmt.tprintf("unknown tool: %s", tool_name), context.temp_allocator)
}

@(private="file")
_handle_resources_list :: proc(s: ^MCPServer, id: RPCID) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, `{"resources":[`)
	for res, i in s.resources {
		if i > 0 { strings.write_byte(&b, ',') }
		strings.write_string(&b, `{"uri":`)
		json_escape_string(&b, res.uri)
		strings.write_string(&b, `,"name":`)
		json_escape_string(&b, res.name)
		if res.description != "" {
			strings.write_string(&b, `,"description":`)
			json_escape_string(&b, res.description)
		}
		if res.mime_type != "" {
			strings.write_string(&b, `,"mimeType":`)
			json_escape_string(&b, res.mime_type)
		}
		strings.write_byte(&b, '}')
	}
	strings.write_string(&b, `]}`)
	return build_success_response(id, strings.to_string(b), context.temp_allocator)
}

@(private="file")
_handle_resources_read :: proc(s: ^MCPServer, id: RPCID, params: json.Value) -> string {
	params_obj, is_obj := params.(json.Object)
	if !is_obj {
		return build_error_response(id, ERR_INVALID_PARAMS, "params must be an object", context.temp_allocator)
	}

	uri_val, has_uri := params_obj["uri"]
	if !has_uri {
		return build_error_response(id, ERR_INVALID_PARAMS, "missing 'uri'", context.temp_allocator)
	}
	uri_str, is_str := uri_val.(json.String)
	if !is_str {
		return build_error_response(id, ERR_INVALID_PARAMS, "'uri' must be a string", context.temp_allocator)
	}
	uri := string(uri_str)

	for res in s.resources {
		if res.uri != uri { continue }

		rr: Resource_Result
		if res.context_handler != nil {
			rr = res.context_handler(s.user_context, uri, context.temp_allocator)
		} else {
			rr = res.simple_handler(uri, context.temp_allocator)
		}

		if rr.is_error {
			return build_error_response(id, ERR_INTERNAL_ERROR, rr.error_message, context.temp_allocator)
		}

		b := strings.builder_make(context.temp_allocator)
		strings.write_string(&b, `{"contents":[{"uri":`)
		json_escape_string(&b, uri)
		mime := rr.mime_type if rr.mime_type != "" else res.mime_type
		if mime != "" {
			strings.write_string(&b, `,"mimeType":`)
			json_escape_string(&b, mime)
		}
		strings.write_string(&b, `,"text":`)
		json_escape_string(&b, rr.content)
		strings.write_string(&b, `}]}`)
		return build_success_response(id, strings.to_string(b), context.temp_allocator)
	}

	return build_error_response(id, ERR_METHOD_NOT_FOUND,
		fmt.tprintf("unknown resource: %s", uri), context.temp_allocator)
}

@(private="file")
_handle_prompts_list :: proc(s: ^MCPServer, id: RPCID) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, `{"prompts":[`)
	for p, i in s.prompts {
		if i > 0 { strings.write_byte(&b, ',') }
		strings.write_string(&b, `{"name":`)
		json_escape_string(&b, p.name)
		if p.description != "" {
			strings.write_string(&b, `,"description":`)
			json_escape_string(&b, p.description)
		}
		if len(p.arguments) > 0 {
			strings.write_string(&b, `,"arguments":[`)
			for arg, j in p.arguments {
				if j > 0 { strings.write_byte(&b, ',') }
				strings.write_string(&b, `{"name":`)
				json_escape_string(&b, arg.name)
				if arg.description != "" {
					strings.write_string(&b, `,"description":`)
					json_escape_string(&b, arg.description)
				}
				strings.write_string(&b, `,"required":`)
				strings.write_string(&b, "true" if arg.required else "false")
				strings.write_byte(&b, '}')
			}
			strings.write_byte(&b, ']')
		}
		strings.write_byte(&b, '}')
	}
	strings.write_string(&b, `]}`)
	return build_success_response(id, strings.to_string(b), context.temp_allocator)
}

@(private="file")
_handle_prompts_get :: proc(s: ^MCPServer, id: RPCID, params: json.Value) -> string {
	params_obj, is_obj := params.(json.Object)
	if !is_obj {
		return build_error_response(id, ERR_INVALID_PARAMS, "params must be an object", context.temp_allocator)
	}

	name_val, has_name := params_obj["name"]
	if !has_name {
		return build_error_response(id, ERR_INVALID_PARAMS, "missing 'name'", context.temp_allocator)
	}
	name_str, is_str := name_val.(json.String)
	if !is_str {
		return build_error_response(id, ERR_INVALID_PARAMS, "'name' must be a string", context.temp_allocator)
	}

	// Build args map from params.arguments object.
	args := make(map[string]string, context.temp_allocator)
	if args_val, has_args := params_obj["arguments"]; has_args {
		if args_obj, is_aobj := args_val.(json.Object); is_aobj {
			for k, v in args_obj {
				if sv, ok := v.(json.String); ok {
					args[k] = string(sv)
				}
			}
		}
	}

	for p in s.prompts {
		if p.name != string(name_str) { continue }

		messages: []Prompt_Message
		if p.context_handler != nil {
			messages = p.context_handler(s.user_context, args, context.temp_allocator)
		} else {
			messages = p.simple_handler(args, context.temp_allocator)
		}

		b := strings.builder_make(context.temp_allocator)
		if p.description != "" {
			strings.write_string(&b, `{"description":`)
			json_escape_string(&b, p.description)
			strings.write_string(&b, `,"messages":[`)
		} else {
			strings.write_string(&b, `{"messages":[`)
		}
		for msg, i in messages {
			if i > 0 { strings.write_byte(&b, ',') }
			strings.write_string(&b, `{"role":`)
			json_escape_string(&b, msg.role)
			strings.write_string(&b, `,"content":{"type":"text","text":`)
			json_escape_string(&b, msg.content)
			strings.write_string(&b, `}}`)
		}
		strings.write_string(&b, `]}`)
		return build_success_response(id, strings.to_string(b), context.temp_allocator)
	}

	return build_error_response(id, ERR_METHOD_NOT_FOUND,
		fmt.tprintf("unknown prompt: %s", name_str), context.temp_allocator)
}
