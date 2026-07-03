package mcp

import "core:encoding/json"
import "core:strings"
import "core:testing"

@(test)
json_strings_escape_all_control_characters :: proc(t: ^testing.T) {
	b := strings.builder_make(context.temp_allocator)
	json_escape_string(&b, "quote\" slash\\ backspace\b formfeed\f newline\n control\x01")
	payload := strings.to_string(b)
	_, err := json.parse(transmute([]u8)payload, allocator = context.temp_allocator)
	testing.expect(t, err == nil, "json_escape_string must always produce valid JSON")
}

@(test)
protocol_version_is_current :: proc(t: ^testing.T) {
	testing.expect_value(t, MCP_PROTOCOL_VERSION, "2025-11-25")
}

