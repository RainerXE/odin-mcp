// types.odin — Core MCP protocol types, constants, and the MCPServer struct.
package mcp

import "core:encoding/json"

// ── JSON-RPC 2.0 ID ───────────────────────────────────────────────────────────
RPCID :: union { i64, string }

// ── Incoming message ──────────────────────────────────────────────────────────
MCPRequest :: struct {
    id:     RPCID,
    method: string,
    params: json.Value,
}

// ── Error codes ───────────────────────────────────────────────────────────────
ERR_PARSE_ERROR      :: -32700
ERR_INVALID_REQUEST  :: -32600
ERR_METHOD_NOT_FOUND :: -32601
ERR_INVALID_PARAMS   :: -32602
ERR_INTERNAL_ERROR   :: -32603

// MCP protocol version this library implements.
MCP_PROTOCOL_VERSION :: "2024-11-05"

// ── Server ────────────────────────────────────────────────────────────────────

// MCPServer holds server identity, registered tools, resources, prompts,
// optional shared context, and optional middleware.
MCPServer :: struct {
    name:         string,
    version:      string,
    tools:        [dynamic]Tool,
    resources:    [dynamic]Resource_Def,
    prompts:      [dynamic]Prompt_Def,

    // user_context is passed to Context_Tool_Handler / Context_Resource_Handler
    // / Context_Prompt_Handler calls.  Set with server_set_context.
    user_context: rawptr,

    // middleware hooks — both are optional (nil = no hook).
    middleware:   Middleware,

    // validation — when true, required fields are checked before dispatch.
    validate_input: bool,
}
