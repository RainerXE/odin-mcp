/*
	odin-mcp — Reusable MCP Protocol Library

	Newline-delimited JSON for the MCP stdio transport.
*/
package mcp

import "core:bufio"
import "core:io"
import "core:os"
import "core:strings"
import "base:runtime"

// read_message reads one newline-delimited MCP message from reader.
// Returns the raw JSON bytes on success (allocated with allocator).
// Returns ok=false on EOF or an empty message — the caller should exit cleanly.
read_message :: proc(reader: ^bufio.Reader, allocator: runtime.Allocator) -> (json_bytes: []u8, ok: bool) {
	line, err := bufio.reader_read_string(reader, '\n', context.temp_allocator)
	if err != nil {
		return nil, false
	}
	line = strings.trim_right(line, "\r\n")
	if line == "" {
		return nil, false
	}
	buf := make([]u8, len(line), allocator)
	copy(buf, transmute([]u8)line)
	return buf, true
}

// write_message writes one JSON message followed by a newline to stdout.
// json_bytes must be the complete JSON payload.
write_message :: proc(json_bytes: []u8) -> bool {
	w := os.to_writer(os.stdout)
	_, err1 := io.write(w, json_bytes)
	_, err2 := io.write_string(w, "\n")
	return err1 == nil && err2 == nil
}

// write_string_message is a convenience wrapper for string payloads.
write_string_message :: proc(s: string) -> bool {
	return write_message(transmute([]u8)s)
}
