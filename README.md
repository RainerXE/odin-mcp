# odin-mcp

A minimal, dependency-free [Model Context Protocol](https://modelcontextprotocol.io) server library for the [Odin programming language](https://odin-lang.org).

Lets any Odin program expose tools, resources, and prompts to Claude Code, Claude Desktop, and other MCP clients over stdio in fewer than 40 lines of code.

---

## Quick start

```odin
package my_server

import mcp "vendor/odin-mcp/mcp"
import "core:encoding/json"
import "base:runtime"

_greet_handler :: proc(params: json.Value, allocator: runtime.Allocator) -> mcp.Tool_Result {
    return mcp.tool_ok(`"Hello from Odin!"`, allocator)
}

main :: proc() {
    s: mcp.MCPServer
    mcp.server_init(&s, "my-server", "1.0.0")

    mcp.server_register_tool(&s, mcp.Tool{
        defn = mcp.ToolDefinition{
            name         = "greet",
            description  = "Say hello",
            input_schema = `{"type":"object","properties":{}}`,
        },
        simple_handler = _greet_handler,
    })

    mcp.server_run(&s)
}
```

Register in `~/.claude/mcp_servers.json`:

```json
{
  "mcpServers": {
    "my-server": { "command": "/path/to/my_server", "args": [] }
  }
}
```

---

## API

### Lifecycle

```odin
server_init(s: ^MCPServer, name: string, version: string)
server_set_context(s: ^MCPServer, ctx: rawptr)       // optional shared state
server_register_tool(s: ^MCPServer, tool: Tool)
server_register_resource(s: ^MCPServer, res: Resource_Def)
server_register_prompt(s: ^MCPServer, p: Prompt_Def)
server_run(s: ^MCPServer)                            // blocks until stdin EOF
```

### Tool handler signatures

```odin
// Simple handler — no shared state needed
Simple_Tool_Handler :: #type proc(params: json.Value, allocator: runtime.Allocator) -> Tool_Result

// Context handler — receives the rawptr set via server_set_context
Context_Tool_Handler :: #type proc(ctx: rawptr, params: json.Value, allocator: runtime.Allocator) -> Tool_Result
```

Set exactly one of `simple_handler` or `context_handler` on `Tool`. The other must be `nil`.

### Tool result constructors

```odin
tool_ok(text: string, allocator) -> Tool_Result
tool_error(kind: Tool_Error_Kind, message: string, allocator) -> Tool_Result
tool_invalid(field: string, reason: string, allocator) -> Tool_Result
```

`Tool_Error_Kind` values: `None`, `Invalid_Params`, `Not_Found`, `Conflict`, `Unavailable`, `Timeout`, `Cancelled`, `Internal`.

### Resources

```odin
Resource_Def :: struct {
    uri:             string,
    name:            string,
    description:     string,
    mime_type:       string,
    simple_handler:  Resource_Handler,         // or
    context_handler: Context_Resource_Handler,
}

resource_ok(content: string, mime: string) -> Resource_Result
resource_error(msg: string)               -> Resource_Result
```

### Prompts

```odin
Prompt_Def :: struct {
    name:            string,
    description:     string,
    arguments:       []Prompt_Arg,
    simple_handler:  Prompt_Handler,           // or
    context_handler: Context_Prompt_Handler,
}
```

### Middleware

```odin
Middleware :: struct {
    before_tool: Before_Tool_Hook,   // called before each tool handler
    after_tool:  After_Tool_Hook,    // called after, with elapsed_ms
}
```

Assign to `s.middleware` before calling `server_run`. Both hooks are optional (`nil` = skip).

### JSON helpers

```odin
json_escape_string(b: ^strings.Builder, s: string)
build_success_response(id: RPCID, result: string, allocator) -> string
build_error_response(id: RPCID, code: int, message: string, allocator) -> string
build_tool_result_from(id: RPCID, result: Tool_Result, allocator) -> string
```

---

## Memory model

All per-request allocations use `context.temp_allocator`. The server calls `free_all(context.temp_allocator)` at the end of every loop iteration, so tool handlers can allocate freely without manual cleanup.

Long-lived data (a database handle, cached config, etc.) should be allocated before calling `server_run` and passed in via `server_set_context`.

---

## Protocol

Implements [MCP 2024-11-05](https://modelcontextprotocol.io/specification) over stdio with Content-Length framing (identical to LSP).

Supported methods: `initialize`, `initialized`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/list`, `prompts/get`.

---

## Integration

This library is used by [olt](https://github.com/RainerXE/odintooling) — the Odin Language Tools static analyser — as its MCP server transport layer.

---

## License

[MIT](https://en.wikipedia.org/wiki/MIT_License)

> "There is no delight in owning anything unshared." — Seneca
