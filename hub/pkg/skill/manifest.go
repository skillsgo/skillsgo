package skill

import (
	"bytes"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"

	"gopkg.in/yaml.v3"
)

var skillNamePattern = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)

func extractManifest(skillFile []byte) (manifest, body []byte, err error) {
	lines := bytes.SplitAfter(skillFile, []byte("\n"))
	if len(lines) == 0 || !isFrontmatterDelimiter(lines[0]) {
		return nil, nil, fmt.Errorf("SKILL.md must start with YAML frontmatter")
	}

	for i := 1; i < len(lines); i++ {
		if !isFrontmatterDelimiter(lines[i]) {
			continue
		}
		manifest = bytes.TrimSpace(bytes.Join(lines[1:i], nil))
		if len(manifest) == 0 {
			return nil, nil, fmt.Errorf("SKILL.md frontmatter must not be empty")
		}
		manifest = append(append([]byte(nil), manifest...), '\n')
		body = append([]byte(nil), bytes.Join(lines[i+1:], nil)...)
		return manifest, body, nil
	}

	return nil, nil, fmt.Errorf("SKILL.md frontmatter is missing its closing delimiter")
}

func validateManifest(manifest, body []byte, expectedName string) error {
	var document yaml.Node
	if err := yaml.Unmarshal(manifest, &document); err != nil || len(document.Content) != 1 {
		return fmt.Errorf("invalid SKILL.md frontmatter")
	}
	root := document.Content[0]
	if root.Kind != yaml.MappingNode {
		return fmt.Errorf("SKILL.md frontmatter must be a YAML mapping")
	}

	fields := make(map[string]*yaml.Node, len(root.Content)/2)
	for i := 0; i < len(root.Content); i += 2 {
		key, value := root.Content[i], root.Content[i+1]
		if key.Kind != yaml.ScalarNode || key.Tag != "!!str" {
			return fmt.Errorf("SKILL.md frontmatter field names must be strings")
		}
		fields[key.Value] = value
	}

	name, err := requiredStringField(fields, "name")
	if err != nil {
		return err
	}
	if utf8.RuneCountInString(name) > 64 || !skillNamePattern.MatchString(name) {
		return fmt.Errorf(`field "name" must be 1-64 characters of lowercase letters, numbers, and single hyphens`)
	}
	if name != expectedName {
		return fmt.Errorf(`field "name" %q must match Skill directory name %q`, name, expectedName)
	}

	description, err := requiredStringField(fields, "description")
	if err != nil {
		return err
	}
	if utf8.RuneCountInString(description) > 1024 {
		return fmt.Errorf(`field "description" must not exceed 1024 characters`)
	}

	if err := optionalStringField(fields, "license", 0); err != nil {
		return err
	}
	if err := optionalStringField(fields, "compatibility", 500); err != nil {
		return err
	}
	if err := optionalStringField(fields, "allowed-tools", 0); err != nil {
		return err
	}
	if metadata, ok := fields["metadata"]; ok {
		if metadata.Kind != yaml.MappingNode {
			return fmt.Errorf(`field "metadata" must be a string-to-string mapping`)
		}
		for i := 0; i < len(metadata.Content); i += 2 {
			if metadata.Content[i].Tag != "!!str" || metadata.Content[i+1].Tag != "!!str" {
				return fmt.Errorf(`field "metadata" must be a string-to-string mapping`)
			}
		}
	}
	if len(bytes.TrimSpace(body)) == 0 {
		return fmt.Errorf("SKILL.md must contain Markdown instructions after frontmatter")
	}
	return nil
}

func requiredStringField(fields map[string]*yaml.Node, name string) (string, error) {
	value, ok := fields[name]
	if !ok || value.Kind != yaml.ScalarNode || value.Tag != "!!str" || strings.TrimSpace(value.Value) == "" {
		return "", fmt.Errorf(`missing or invalid required string field %q in SKILL.md frontmatter`, name)
	}
	return value.Value, nil
}

func optionalStringField(fields map[string]*yaml.Node, name string, maxLength int) error {
	value, ok := fields[name]
	if !ok {
		return nil
	}
	if value.Kind != yaml.ScalarNode || value.Tag != "!!str" || strings.TrimSpace(value.Value) == "" {
		return fmt.Errorf(`field %q must be a non-empty string`, name)
	}
	if maxLength > 0 && utf8.RuneCountInString(value.Value) > maxLength {
		return fmt.Errorf(`field %q must not exceed %d characters`, name, maxLength)
	}
	return nil
}

func isFrontmatterDelimiter(line []byte) bool {
	return bytes.Equal(bytes.TrimSpace(line), []byte("---"))
}
