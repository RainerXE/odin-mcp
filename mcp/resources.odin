// resources.odin — MCP resource support (read-only named data endpoints).
// Resources let clients fetch named data without a tool call.
// The server handles resources/list and resources/read automatically.
package mcp

import "base:runtime"

// Resource_Result is returned by resource handlers.
Resource_Result :: struct {
    content:       string,
    mime_type:     string, // e.g. "application/json", "text/plain"
    is_error:      bool,
    error_message: string,
}

// Resource_Handler is the simple (no-context) resource handler signature.
Resource_Handler :: #type proc(
    uri:       string,
    allocator: runtime.Allocator,
) -> Resource_Result

// Context_Resource_Handler receives the server's user_context in addition.
Context_Resource_Handler :: #type proc(
    ctx:       rawptr,
    uri:       string,
    allocator: runtime.Allocator,
) -> Resource_Result

// Resource_Def describes a single resource.
Resource_Def :: struct {
    uri:              string, // e.g. "olt://rules"
    name:             string, // human-readable name
    description:      string,
    mime_type:        string, // default MIME type for responses

    simple_handler:   Resource_Handler,         // set one
    context_handler:  Context_Resource_Handler, // or the other
}

// resource_ok builds a successful Resource_Result.
resource_ok :: proc(content: string, mime: string = "application/json") -> Resource_Result {
    return Resource_Result{content = content, mime_type = mime, is_error = false}
}

// resource_error builds a failure Resource_Result.
resource_error :: proc(msg: string) -> Resource_Result {
    return Resource_Result{content = msg, is_error = true, error_message = msg}
}
