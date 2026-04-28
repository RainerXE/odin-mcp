// errors.odin — Tool error kinds and JSON-RPC error codes.
package mcp

// Tool_Error_Kind gives MCP clients a machine-readable reason for a tool failure.
// The server maps these to JSON-RPC error codes and "isError":true content.
Tool_Error_Kind :: enum {
    None,            // success — not an error
    Invalid_Params,  // required field missing or wrong type  (-32602)
    Not_Found,       // tool, resource, or referenced object does not exist
    Conflict,        // object already exists / already in requested state
    Unavailable,     // backend, database, or dependency not ready
    Timeout,         // operation exceeded time limit
    Cancelled,       // explicitly cancelled by the client
    Internal,        // unexpected error inside the handler
}

// error_kind_to_rpc_code maps a Tool_Error_Kind to a JSON-RPC 2.0 error code.
error_kind_to_rpc_code :: proc(k: Tool_Error_Kind) -> int {
    switch k {
    case .Invalid_Params: return ERR_INVALID_PARAMS
    case .Not_Found:      return -32001
    case .Conflict:       return -32002
    case .Unavailable:    return -32003
    case .Timeout:        return -32004
    case .Cancelled:      return -32005
    case .None, .Internal: return ERR_INTERNAL_ERROR
    }
    return ERR_INTERNAL_ERROR
}
