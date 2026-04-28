// json_helpers.odin — JSON building helpers for MCP responses.
package mcp

import "base:runtime"
import "core:fmt"
import "core:strings"

// json_escape_string writes s as a JSON-quoted, escaped string into b.
json_escape_string :: proc(b: ^strings.Builder, s: string) {
	strings.write_byte(b, '"')
	for c in s {
		switch c {
		case '"':  strings.write_string(b, `\"`)
		case '\\': strings.write_string(b, `\\`)
		case '\n': strings.write_string(b, `\n`)
		case '\r': strings.write_string(b, `\r`)
		case '\t': strings.write_string(b, `\t`)
		case:      strings.write_rune(b, c)
		}
	}
	strings.write_byte(b, '"')
}

// rpcid_to_json writes the JSON representation of id into b.
// Absent id (zero union) → "null".
rpcid_to_json :: proc(b: ^strings.Builder, id: RPCID) {
	switch v in id {
	case i64:    fmt.sbprint(b, v)
	case string: json_escape_string(b, v)
	case:        strings.write_string(b, "null")
	}
}

// build_success_response wraps a pre-serialised result JSON fragment in a
// JSON-RPC 2.0 success envelope.
build_success_response :: proc(id: RPCID, result: string, allocator: runtime.Allocator) -> string {
	b := strings.builder_make(allocator)
	strings.write_string(&b, `{"jsonrpc":"2.0","id":`)
	rpcid_to_json(&b, id)
	strings.write_string(&b, `,"result":`)
	strings.write_string(&b, result)
	strings.write_byte(&b, '}')
	return strings.to_string(b)
}

// build_error_response builds a JSON-RPC 2.0 error envelope.
build_error_response :: proc(id: RPCID, code: int, message: string, allocator: runtime.Allocator) -> string {
	b := strings.builder_make(allocator)
	strings.write_string(&b, `{"jsonrpc":"2.0","id":`)
	rpcid_to_json(&b, id)
	strings.write_string(&b, `,"error":{"code":`)
	fmt.sbprint(&b, code)
	strings.write_string(&b, `,"message":`)
	json_escape_string(&b, message)
	strings.write_string(&b, `}}`)
	return strings.to_string(b)
}

// build_tool_result_from builds a MCP CallToolResult JSON-RPC response from a Tool_Result.
// Handles multiple content items and maps error_kind to an RPC error code when is_error=true.
build_tool_result_from :: proc(id: RPCID, result: Tool_Result, allocator: runtime.Allocator) -> string {
	b := strings.builder_make(allocator)
	strings.write_string(&b, `{"jsonrpc":"2.0","id":`)
	rpcid_to_json(&b, id)
	strings.write_string(&b, `,"result":{"content":[`)
	for item, i in result.content {
		if i > 0 { strings.write_byte(&b, ',') }
		strings.write_string(&b, `{"type":"text","text":`)
		json_escape_string(&b, item.text)
		strings.write_byte(&b, '}')
	}
	strings.write_string(&b, `],"isError":`)
	strings.write_string(&b, "true" if result.is_error else "false")
	strings.write_string(&b, `}}`)
	return strings.to_string(b)
}
