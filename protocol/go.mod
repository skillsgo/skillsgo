// [INPUT]: Depends on the Go toolchain, Go semantic-version rules, and YAML frontmatter parsing.
// [OUTPUT]: Defines the reproducible dependency graph for the shared SkillsGo protocol workspace.
// [POS]: Serves as the F2 build manifest consumed by the CLI and Hub workspaces.
// [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
module github.com/skillsgo/skillsgo/protocol

go 1.25.0

require (
	golang.org/x/mod v0.37.0
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/kr/pretty v0.3.1 // indirect
	github.com/rogpeppe/go-internal v1.15.0 // indirect
	gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c // indirect
)
