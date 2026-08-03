# SkillsGo npm distribution

The release pipeline publishes the unscoped `skillsgo` package together with
platform-specific optional dependencies. This keeps the user-facing command
short while the native Go executable remains the source of truth.

```sh
npx skillsgo --help
npm install --global skillsgo
skillsgo --help
```

The package supports macOS arm64/x86_64, Linux arm64/x86_64, and Windows
x86_64. An unsupported operating system or architecture fails with an explicit
message instead of silently running a different binary.
