# Issue Tracker: GitHub

Issues and PRDs for this repository live in GitHub Issues under `skillsgo/skillsgo`. Use the `gh` CLI for all operations.

## Conventions

- Create an issue with `gh issue create --title "..." --body-file <file>`.
- Read an issue with `gh issue view <number> --comments`, including labels when relevant.
- List issues with `gh issue list --state open --json number,title,body,labels,comments` and the appropriate state or label filters.
- Comment with `gh issue comment <number> --body "..."`.
- Apply or remove labels with `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- Close an issue with `gh issue close <number> --comment "..."`.

Infer the repository from `git remote -v`; `gh` resolves it automatically inside this clone.

## Pull Requests as a Triage Surface

**PRs as a request surface: no.**

GitHub shares one number space across issues and pull requests. Resolve an ambiguous reference with `gh pr view <number>` and fall back to `gh issue view <number>`.

## Publishing and Fetching

- When a skill says "publish to the issue tracker," create a GitHub Issue.
- When a skill says "fetch the relevant ticket," run `gh issue view <number> --comments`.

## Wayfinding Operations

- A map is one GitHub Issue labeled `wayfinder:map`.
- Child tickets use GitHub sub-issues when available and otherwise link back with `Part of #<map>`.
- Represent blocking with GitHub native issue dependencies when available; otherwise use a `Blocked by: #<number>` line.
- Claim work with `gh issue edit <number> --add-assignee @me`.
- Resolve work by commenting with the result, closing the issue, and recording the decision in the map.
