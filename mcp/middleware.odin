// middleware.odin — Optional request/tool lifecycle hooks.
package mcp

// Hook_Result controls whether the server proceeds after a before-hook.
Hook_Result :: enum { Continue, Abort }

// Before_Tool_Hook is called before a tool handler.
// Return .Abort to skip the handler and return an Internal error.
Before_Tool_Hook :: #type proc(
    ctx:       rawptr,
    tool_name: string,
) -> Hook_Result

// After_Tool_Hook is called after a tool handler completes (including errors).
// elapsed_ms is the handler wall-clock time in milliseconds.
After_Tool_Hook :: #type proc(
    ctx:        rawptr,
    tool_name:  string,
    result:     ^Tool_Result,
    elapsed_ms: int,
)

// Middleware groups the optional lifecycle hooks.
// Set only the hooks you need; nil hooks are skipped.
Middleware :: struct {
    before_tool: Before_Tool_Hook, // nil = no pre-hook
    after_tool:  After_Tool_Hook,  // nil = no post-hook
}
