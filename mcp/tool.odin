// tool.odin — Tool registration types, result types, and handler signatures.
package mcp

import "core:encoding/json"
import "core:fmt"
import "base:runtime"

// ── Handler signatures ────────────────────────────────────────────────────────

// Simple_Tool_Handler is the standard handler signature.
// Use this when the tool needs only the request parameters.
Simple_Tool_Handler :: #type proc(
    params:    json.Value,
    allocator: runtime.Allocator,
) -> Tool_Result

// Context_Tool_Handler receives the server's user_context pointer in addition
// to the request parameters.  Cast ctx to your concrete server-state type.
//
//   _my_handler :: proc(ctx: rawptr, params: json.Value, alloc: runtime.Allocator) -> mcp.Tool_Result {
//       state := cast(^My_State)ctx
//       // use state.db, state.config, etc.
//   }
Context_Tool_Handler :: #type proc(
    ctx:       rawptr,
    params:    json.Value,
    allocator: runtime.Allocator,
) -> Tool_Result

// ToolHandler is a backward-compatible alias for Simple_Tool_Handler.
// Deprecated: use Simple_Tool_Handler or Context_Tool_Handler.
ToolHandler :: Simple_Tool_Handler

// ── Tool definition ───────────────────────────────────────────────────────────

// ToolDefinition describes a tool for the tools/list response.
ToolDefinition :: struct {
    name:         string,
    description:  string,
    input_schema: string, // verbatim JSON Schema object
}

// Tool pairs a definition with its handler(s).
// Set exactly one of simple_handler or context_handler.
Tool :: struct {
    defn:            ToolDefinition,
    simple_handler:  Simple_Tool_Handler,   // nil if using context_handler
    context_handler: Context_Tool_Handler,  // nil if using simple_handler
}

// RegisteredTool is a backward-compatible alias for Tool.
// Deprecated: use Tool directly.
RegisteredTool :: Tool

// ── Tool result ───────────────────────────────────────────────────────────────

// Tool_Content_Kind identifies the type of content in a Tool_Content item.
Tool_Content_Kind :: enum { Text }

// Tool_Content holds one item in a tool result's content array.
Tool_Content :: struct {
    kind: Tool_Content_Kind,
    text: string,
}

// Tool_Result is the return type for all tool handlers.
// On success: is_error=false, error_kind=.None, content holds the payload.
// On failure: is_error=true, error_kind describes the problem, error_message is human-readable.
Tool_Result :: struct {
    content:       []Tool_Content,
    is_error:      bool,
    error_kind:    Tool_Error_Kind,
    error_message: string,
}

// ── Constructors ──────────────────────────────────────────────────────────────

// tool_ok returns a successful Tool_Result with a single text content item.
tool_ok :: proc(text: string, allocator: runtime.Allocator) -> Tool_Result {
    content    := make([]Tool_Content, 1, allocator)
    content[0]  = Tool_Content{kind = .Text, text = text}
    return Tool_Result{content = content, is_error = false, error_kind = .None}
}

// tool_error returns a failure Tool_Result with a structured error kind.
tool_error :: proc(kind: Tool_Error_Kind, message: string, allocator: runtime.Allocator) -> Tool_Result {
    content    := make([]Tool_Content, 1, allocator)
    content[0]  = Tool_Content{kind = .Text, text = message}
    return Tool_Result{
        content       = content,
        is_error      = true,
        error_kind    = kind,
        error_message = message,
    }
}

// tool_invalid returns a failure Tool_Result for missing or invalid parameters.
tool_invalid :: proc(field: string, reason: string, allocator: runtime.Allocator) -> Tool_Result {
    msg := fmt.aprintf("invalid param '%s': %s", field, reason, allocator)
    return tool_error(.Invalid_Params, msg, allocator)
}
