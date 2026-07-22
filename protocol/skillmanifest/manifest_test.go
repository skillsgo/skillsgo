/*
 * [INPUT]: Uses complete, minimally valid, malformed, type-invalid, length-boundary, and body-empty SKILL.md documents.
 * [OUTPUT]: Specifies lossless splitting, tolerant typed parsing, strict publication schema, optional fields, metadata types, and name grammar.
 * [POS]: Serves as exhaustive manifest-format compatibility coverage shared by Hub publication and CLI reads.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillmanifest

import (
	"strings"
	"testing"
)

func document(frontmatter, body string) []byte {
	return []byte("---\n" + frontmatter + "\n---\n" + body)
}

func TestSplitPreservesFrontmatterAndBody(t *testing.T) {
	input := document("name: demo\ndescription: Example", "# Instructions\n\nDo work.\n")
	frontmatter, body, err := Split(input)
	if err != nil {
		t.Fatal(err)
	}
	if string(frontmatter) != "name: demo\ndescription: Example\n" || string(body) != "# Instructions\n\nDo work.\n" {
		t.Fatalf("split mismatch: %q / %q", frontmatter, body)
	}
	for _, test := range []struct {
		name     string
		input    []byte
		contains string
	}{{"no frontmatter", []byte("# Skill"), "must start"}, {"empty frontmatter", []byte("---\n---\nbody"), "must not be empty"}, {"missing close", []byte("---\nname: demo\n"), "missing its closing"}} {
		t.Run(test.name, func(t *testing.T) {
			_, _, err := Split(test.input)
			if err == nil || !strings.Contains(err.Error(), test.contains) {
				t.Fatalf("error %v, want %q", err, test.contains)
			}
		})
	}
}

func TestParseTypedManifestWithoutPublicationPolicy(t *testing.T) {
	input := document("name: Demo\ndescription: Example\nlicense: MIT\ncompatibility: Codex\nallowed-tools: Read\nmetadata:\n  owner: team", "body")
	manifest, body, err := Parse(input)
	if err != nil {
		t.Fatal(err)
	}
	if manifest.Name != "Demo" || manifest.License != "MIT" || manifest.Metadata["owner"] != "team" || string(body) != "body" {
		t.Fatalf("unexpected parse: %#v / %q", manifest, body)
	}
	if _, _, err := Parse([]byte("no frontmatter")); err == nil {
		t.Fatal("expected split failure")
	}
	if _, _, err := Parse(document("name: [", "body")); err == nil || !strings.Contains(err.Error(), "invalid SKILL.md frontmatter") {
		t.Fatalf("invalid YAML error: %v", err)
	}
}

func TestValidatePublishedCompleteManifest(t *testing.T) {
	input := document("name: demo-skill\ndescription: Example\nlicense: MIT\ncompatibility: Codex 1\nallowed-tools: Read Write\nmetadata:\n  owner: team", "# Instructions")
	manifest, err := ValidatePublished(input)
	if err != nil {
		t.Fatal(err)
	}
	if manifest.Name != "demo-skill" || manifest.Description != "Example" || manifest.Compatibility != "Codex 1" || manifest.AllowedTools != "Read Write" || manifest.Metadata["owner"] != "team" {
		t.Fatalf("unexpected manifest %#v", manifest)
	}
	frontmatter, body, err := Split(input)
	if err != nil {
		t.Fatal(err)
	}
	fromParts, err := Validate(frontmatter, body)
	if err != nil || fromParts.Name != manifest.Name {
		t.Fatalf("Validate parts=%#v,%v", fromParts, err)
	}
}

func TestValidateRejectsSchemaAndContentViolations(t *testing.T) {
	longName := strings.Repeat("a", 65)
	longDescription := strings.Repeat("界", 1025)
	longCompatibility := strings.Repeat("x", 501)
	tests := []struct{ name, frontmatter, body, contains string }{
		{"invalid YAML", "name: [", "body", "YAML mapping"}, {"scalar root", "hello", "body", "YAML mapping"}, {"non-string key", "1: value\nname: demo\ndescription: Example", "body", "field names must be strings"},
		{"missing name", "description: Example", "body", "required string field \"name\""}, {"numeric name", "name: 1\ndescription: Example", "body", "required string field \"name\""}, {"blank name", "name: '  '\ndescription: Example", "body", "required string field \"name\""},
		{"uppercase name", "name: Demo\ndescription: Example", "body", "field \"name\""}, {"double hyphen", "name: demo--skill\ndescription: Example", "body", "field \"name\""}, {"long name", "name: " + longName + "\ndescription: Example", "body", "field \"name\""},
		{"missing description", "name: demo", "body", "required string field \"description\""}, {"numeric description", "name: demo\ndescription: 1", "body", "required string field \"description\""}, {"long description", "name: demo\ndescription: " + longDescription, "body", "must not exceed 1024"},
		{"blank license", "name: demo\ndescription: Example\nlicense: ''", "body", "license"}, {"numeric tools", "name: demo\ndescription: Example\nallowed-tools: 1", "body", "allowed-tools"}, {"long compatibility", "name: demo\ndescription: Example\ncompatibility: " + longCompatibility, "body", "must not exceed 500"},
		{"metadata sequence", "name: demo\ndescription: Example\nmetadata: [one]", "body", "string-to-string mapping"}, {"metadata numeric value", "name: demo\ndescription: Example\nmetadata:\n  owner: 1", "body", "string-to-string mapping"},
		{"empty body", "name: demo\ndescription: Example", " \n", "Markdown instructions"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := Validate([]byte(test.frontmatter+"\n"), []byte(test.body))
			if err == nil || !strings.Contains(err.Error(), test.contains) {
				t.Fatalf("error %v, want %q", err, test.contains)
			}
		})
	}
	if _, err := ValidatePublished([]byte("not frontmatter")); err == nil {
		t.Fatal("ValidatePublished must propagate split failure")
	}
}

func TestNameGrammarBoundaries(t *testing.T) {
	for _, name := range []string{"a", "demo", "demo-skill", strings.Repeat("a", 64)} {
		if !ValidName(name) {
			t.Fatalf("valid name rejected %q", name)
		}
	}
	for _, name := range []string{"", "Demo", "-demo", "demo-", "demo--skill", "demo_skill", strings.Repeat("a", 65)} {
		if ValidName(name) {
			t.Fatalf("invalid name accepted %q", name)
		}
	}
}
