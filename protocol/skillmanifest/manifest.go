/*
 * [INPUT]: Depends on source-authored `SKILL.md` bytes, the Agent Skills YAML frontmatter schema, and the canonical Skill Name grammar.
 * [OUTPUT]: Provides shared frontmatter parsing, typed metadata, and strict publication validation.
 * [POS]: Serves as the executable Skill manifest-format contract for Hub publication and CLI local reads.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillmanifest

import (
	"bytes"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/skillsgo/skillsgo/protocol/skillname"
	"gopkg.in/yaml.v3"
)

type Manifest struct {
	Name          string            `yaml:"name"`
	Description   string            `yaml:"description"`
	License       string            `yaml:"license"`
	Compatibility string            `yaml:"compatibility"`
	AllowedTools  string            `yaml:"allowed-tools"`
	Metadata      map[string]string `yaml:"metadata"`
}

func Split(skillFile []byte) (frontmatter, body []byte, err error) {
	lines := bytes.SplitAfter(skillFile, []byte("\n"))
	if len(lines) == 0 || !delimiter(lines[0]) {
		return nil, nil, fmt.Errorf("SKILL.md must start with YAML frontmatter")
	}
	for index := 1; index < len(lines); index++ {
		if !delimiter(lines[index]) {
			continue
		}
		frontmatter = bytes.TrimSpace(bytes.Join(lines[1:index], nil))
		if len(frontmatter) == 0 {
			return nil, nil, fmt.Errorf("SKILL.md frontmatter must not be empty")
		}
		return append(append([]byte(nil), frontmatter...), '\n'), append([]byte(nil), bytes.Join(lines[index+1:], nil)...), nil
	}
	return nil, nil, fmt.Errorf("SKILL.md frontmatter is missing its closing delimiter")
}

func Parse(skillFile []byte) (Manifest, []byte, error) {
	frontmatter, body, err := Split(skillFile)
	if err != nil {
		return Manifest{}, nil, err
	}
	var manifest Manifest
	if err := yaml.Unmarshal(frontmatter, &manifest); err != nil {
		return Manifest{}, nil, fmt.Errorf("invalid SKILL.md frontmatter")
	}
	return manifest, body, nil
}

func ValidatePublished(skillFile []byte) (Manifest, error) {
	frontmatter, body, err := Split(skillFile)
	if err != nil {
		return Manifest{}, err
	}
	return Validate(frontmatter, body)
}

func Validate(frontmatter, body []byte) (Manifest, error) {
	var document yaml.Node
	if err := yaml.Unmarshal(frontmatter, &document); err != nil || len(document.Content) != 1 || document.Content[0].Kind != yaml.MappingNode {
		return Manifest{}, fmt.Errorf("SKILL.md frontmatter must be a YAML mapping")
	}
	root := document.Content[0]
	fields := make(map[string]*yaml.Node, len(root.Content)/2)
	for i := 0; i < len(root.Content); i += 2 {
		key, value := root.Content[i], root.Content[i+1]
		if key.Kind != yaml.ScalarNode || key.Tag != "!!str" {
			return Manifest{}, fmt.Errorf("SKILL.md frontmatter field names must be strings")
		}
		fields[key.Value] = value
	}
	name, err := required(fields, "name")
	if err != nil {
		return Manifest{}, err
	}
	if !skillname.Valid(name) {
		return Manifest{}, fmt.Errorf(`field "name" must be 1-64 characters of lowercase letters, numbers, and single hyphens`)
	}
	description, err := required(fields, "description")
	if err != nil {
		return Manifest{}, err
	}
	if utf8.RuneCountInString(description) > 1024 {
		return Manifest{}, fmt.Errorf(`field "description" must not exceed 1024 characters`)
	}
	for field, limit := range map[string]int{"license": 0, "compatibility": 500, "allowed-tools": 0} {
		if err := optional(fields, field, limit); err != nil {
			return Manifest{}, err
		}
	}
	if metadata, ok := fields["metadata"]; ok {
		if metadata.Kind != yaml.MappingNode {
			return Manifest{}, fmt.Errorf(`field "metadata" must be a string-to-string mapping`)
		}
		for i := 0; i < len(metadata.Content); i += 2 {
			if metadata.Content[i].Tag != "!!str" || metadata.Content[i+1].Tag != "!!str" {
				return Manifest{}, fmt.Errorf(`field "metadata" must be a string-to-string mapping`)
			}
		}
	}
	if len(bytes.TrimSpace(body)) == 0 {
		return Manifest{}, fmt.Errorf("SKILL.md must contain Markdown instructions after frontmatter")
	}
	var manifest Manifest
	if err := yaml.Unmarshal(frontmatter, &manifest); err != nil {
		return Manifest{}, err
	}
	return manifest, nil
}

func ValidName(name string) bool {
	return skillname.Valid(name)
}
func required(fields map[string]*yaml.Node, name string) (string, error) {
	value, ok := fields[name]
	if !ok || value.Kind != yaml.ScalarNode || value.Tag != "!!str" || strings.TrimSpace(value.Value) == "" {
		return "", fmt.Errorf(`missing or invalid required string field %q in SKILL.md frontmatter`, name)
	}
	return value.Value, nil
}
func optional(fields map[string]*yaml.Node, name string, max int) error {
	value, ok := fields[name]
	if !ok {
		return nil
	}
	if value.Kind != yaml.ScalarNode || value.Tag != "!!str" || strings.TrimSpace(value.Value) == "" {
		return fmt.Errorf(`field %q must be a non-empty string`, name)
	}
	if max > 0 && utf8.RuneCountInString(value.Value) > max {
		return fmt.Errorf(`field %q must not exceed %d characters`, name, max)
	}
	return nil
}
func delimiter(line []byte) bool { return bytes.Equal(bytes.TrimSpace(line), []byte("---")) }
