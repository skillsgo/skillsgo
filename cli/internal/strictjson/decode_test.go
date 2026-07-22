/*
 * [INPUT]: Depends on the strict multi-object decoder and representative machine-input payloads.
 * [OUTPUT]: Specifies successful decoding, unknown-field rejection, trailing-value rejection, and domain-validation diagnostics.
 * [POS]: Serves as the focused contract suite for the shared CLI strict JSON decoding primitive.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package strictjson

import (
	"fmt"
	"testing"
)

func TestDecodeMany(t *testing.T) {
	type request struct {
		Name string `json:"name"`
	}
	items, err := DecodeMany[request]([]string{`{"name":"one"}`, `{"name":"two"}`}, "invalid target", nil)
	if err != nil || len(items) != 2 || items[1].Name != "two" {
		t.Fatalf("DecodeMany() = %#v, %v", items, err)
	}

	tests := []struct {
		name  string
		value string
		check func(request) error
	}{
		{name: "unknown field", value: `{"name":"one","extra":true}`},
		{name: "trailing value", value: `{"name":"one"} {}`},
		{name: "domain validation", value: `{"name":"one"}`, check: func(request) error { return fmt.Errorf("rejected") }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if _, err := DecodeMany([]string{test.value}, "invalid target", test.check); err == nil {
				t.Fatal("DecodeMany() error = nil")
			}
		})
	}
}
