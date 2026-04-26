# odin-mcp

A minimal, dependency-free [Model Context Protocol](https://modelcontextprotocol.io) server library for the [Odin programming language](https://odin-lang.org).

Lets any Odin program expose tools to Claude Code, Claude Desktop, and other MCP clients over stdio in fewer than 30 lines of code.

---

## Quick start

```odin
package my_server

import "vendor/odin-mcp"
import "core:encoding/json"
import "base:runtime"

_greet_handler :: proc(params: json.Value, allocator: runtime.Allocator) -> (string, bool) {
    return `"Hello from Odin!"`, false
}

main :: proc() {
    s: mcp.MCPServer
    mcp.server_init(&s, "my-server", "1.0.0")

    mcp.server_register_tool(&s, mcp.RegisteredTool{
        defn = mcp.ToolDefinition{
            name         = "greet",
            description  = "Say hello",
            input_schema = `{"type":"object","properties":{}}`,
        },
        handler = _greet_handler,
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
server_register_tool(s: ^MCPServer, tool: RegisteredTool)
server_run(s: ^MCPServer)   // blocks until stdin EOF
```

### Tool handler signature

```odin
ToolHandler :: #type proc(params: json.Value, allocator: runtime.Allocator) -> (result: string, is_error: bool)
```

- `params` — the `arguments` field from the MCP `tools/call` request (owned by the server; do not free it)
- `allocator` — request-scoped `context.temp_allocator`; freed automatically after the handler returns
- `result` — a JSON string (any valid JSON value) returned to the client
- `is_error` — `true` signals a tool-level error to the client (the string is an error message)

### JSON helpers

```odin
json_escape_string(b: ^strings.Builder, s: string)
build_success_response(id: RPCID, result: string, allocator) -> string
build_error_response(id: RPCID, code: int, message: string, allocator) -> string
build_tool_result(id: RPCID, content: string, is_error: bool, allocator) -> string
```

---

## Memory model

All per-request allocations use `context.temp_allocator`. The server calls `free_all(context.temp_allocator)` at the end of every loop iteration, so tool handlers can allocate freely without manual cleanup.

Long-lived data (e.g. a database handle your tool reads from) should be allocated with `context.allocator` before calling `server_run`.

---

## Protocol

Implements [MCP 2024-11-05](https://modelcontextprotocol.io/specification) over stdio with Content-Length framing (identical to LSP).

Supported methods: `initialize`, `initialized`, `ping`, `tools/list`, `tools/call`.

---

## Integration

This library is used by [olt](https://github.com/RainerXE/odintooling) — the Odin Language Tools static analyser — as its MCP server transport layer.

---

## License

MIT
