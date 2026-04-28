// prompts.odin — MCP prompt support (reusable templated messages).
// The server handles prompts/list and prompts/get automatically.
package mcp

import "base:runtime"

// Prompt_Arg describes one argument a prompt accepts.
Prompt_Arg :: struct {
    name:        string,
    description: string,
    required:    bool,
}

// Prompt_Message is one message in a prompt response.
Prompt_Message :: struct {
    role:    string, // "user" or "assistant"
    content: string,
}

// Prompt_Handler is the simple (no-context) handler signature.
Prompt_Handler :: #type proc(
    args:      map[string]string,
    allocator: runtime.Allocator,
) -> []Prompt_Message

// Context_Prompt_Handler receives the server's user_context in addition.
Context_Prompt_Handler :: #type proc(
    ctx:       rawptr,
    args:      map[string]string,
    allocator: runtime.Allocator,
) -> []Prompt_Message

// Prompt_Def describes a single prompt template.
Prompt_Def :: struct {
    name:             string,
    description:      string,
    arguments:        []Prompt_Arg,

    simple_handler:   Prompt_Handler,         // set one
    context_handler:  Context_Prompt_Handler, // or the other
}
