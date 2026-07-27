# [INPUT]: Depends on the Hub repository path and its config.dev.yaml example.
# [OUTPUT]: Creates config.yaml when no local Hub configuration exists.
# [POS]: Serves as the Windows development configuration bootstrap script.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
$repoDir = Join-Path $PSScriptRoot ".." | Join-Path -ChildPath ".."
if (-not (Join-Path $repoDir config.yaml | Test-Path)) {
    $example = Join-Path $repoDir config.dev.yaml
    $target = Join-Path $repoDir config.yaml
    Copy-Item $example $target
}
