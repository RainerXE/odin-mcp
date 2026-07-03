package main

import "base:runtime"
import "core:encoding/json"
import mcp "../../mcp"

greet :: proc(params: json.Value, allocator: runtime.Allocator) -> mcp.Tool_Result {
	return mcp.tool_ok(`{"message":"hello from Odin"}`, allocator)
}

main :: proc() {
	server: mcp.MCPServer
	mcp.server_init(&server, "odin-mcp-smoke", "1.0.0")
	mcp.server_register_tool(&server, mcp.Tool{
		defn = mcp.ToolDefinition{
			name = "greet",
			description = "Return a small greeting",
			input_schema = `{"type":"object","properties":{}}`,
		},
		simple_handler = greet,
	})
	mcp.server_run(&server)
}
