// transport.odin — Content-Length framing for the MCP stdio transport.
// Framing is identical to LSP: each message is preceded by
// "Content-Length: N\r\n\r\n" followed by N UTF-8 bytes of JSON.
package mcp

import "base:runtime"
import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "core:strings"

// read_message reads one framed MCP message from reader.
// Returns the raw JSON bytes on success (allocated with allocator).
// Returns ok=false on EOF or a malformed frame.
read_message :: proc(reader: ^bufio.Reader, allocator: runtime.Allocator) -> (json_bytes: []u8, ok: bool) {
	content_length := -1

	for {
		line, err := bufio.reader_read_string(reader, '\n', context.temp_allocator)
		if err != nil {
			return nil, false
		}
		line = strings.trim_right(line, "\r\n")
		if line == "" {
			break
		}
		if strings.has_prefix(line, "Content-Length:") {
			val := strings.trim_space(line[len("Content-Length:"):])
			n, parse_ok := strconv.parse_int(val)
			if !parse_ok || n < 0 {
				return nil, false
			}
			content_length = n
		}
	}

	if content_length < 0 {
		return nil, false
	}
	if content_length == 0 {
		return []u8{}, true
	}

	buf := make([]u8, content_length, allocator)
	total := 0
	for total < content_length {
		n, err := bufio.reader_read(reader, buf[total:])
		total += n
		if err != nil && total < content_length {
			return nil, false
		}
	}
	return buf, true
}

// write_message writes one framed MCP message to stdout.
write_message :: proc(json_bytes: []u8) -> bool {
	header := fmt.tprintf("Content-Length: %d\r\n\r\n", len(json_bytes))
	w := os.to_writer(os.stdout)
	_, err1 := io.write_string(w, header)
	_, err2 := io.write(w, json_bytes)
	return err1 == nil && err2 == nil
}

// write_string_message is a convenience wrapper for string payloads.
write_string_message :: proc(s: string) -> bool {
	return write_message(transmute([]u8)s)
}
