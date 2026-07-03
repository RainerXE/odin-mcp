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

@(test)
json_fragments_are_validated_and_compacted :: proc(t: ^testing.T) {
	b := strings.builder_make(context.temp_allocator)
	ok := json_write_compact_fragment(&b, `{
		"type": "object",
		"properties": {"message": {"const": "a b"}}
	}`)
	payload := strings.to_string(b)

	testing.expect(t, ok, "valid JSON fragment must be accepted")
	_, parse_err := json.parse_string(payload, allocator = context.temp_allocator)
	testing.expect(t, parse_err == nil, "compacted fragment must remain valid JSON")
	testing.expect(
		t,
		!strings.contains(payload, "\n") && !strings.contains(payload, "\r"),
		"compacted fragment must not contain line breaks",
	)
	testing.expect(t, strings.contains(payload, `"a b"`), "string whitespace must be preserved")

	invalid := strings.builder_make(context.temp_allocator)
	testing.expect(
		t,
		!json_write_compact_fragment(&invalid, `{"type":}`),
		"invalid JSON fragment must be rejected",
	)
	testing.expect_value(t, strings.to_string(invalid), "")
}
