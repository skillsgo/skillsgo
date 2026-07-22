#!/bin/sh
# [INPUT]: Depends on git plus a writable disposable /e2e directory.
# [OUTPUT]: Creates deterministic local Git remotes for Repository discovery, version, ancestor-based pseudo-version, movable-branch refresh, history, selector, and invalid-candidate journeys.
# [POS]: Serves as the source-host fixture boundary for cross-product Repository E2E tests.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
set -eu

fixture_root=/e2e/git
work_root=/e2e/git-work
rm -rf "$fixture_root" "$work_root"
mkdir -p "$fixture_root/group/subgroup" "$work_root"
git config --global user.email e2e@skillsgo.local
git config --global user.name "SkillsGo E2E"
git config --global protocol.file.allow always

new_repo() {
  name=$1
  work="$work_root/$name"
  remote="$fixture_root/group/subgroup/$name"
  mkdir -p "$work" "$(dirname "$remote")"
  git -C "$work" init -b main >/dev/null
  git init --bare "$remote" >/dev/null
  git -C "$work" remote add origin "$remote"
}

skill() {
  directory=$1
  name=$2
  description=$3
  mkdir -p "$directory"
  printf '%s\n' '---' "name: $name" "description: $description" '---' "# $name" >"$directory/SKILL.md"
}

commit_push() {
  work=$1
  message=$2
  git -C "$work" add .
  git -C "$work" commit -m "$message" >/dev/null
  git -C "$work" push -u origin main >/dev/null
  remote=$(git -C "$work" remote get-url origin)
  git --git-dir="$remote" symbolic-ref HEAD refs/heads/main
}

new_repo collection
collection="$work_root/collection"
skill "$collection" root-suite "Repository root fixture."
skill "$collection/skills/alpha" alpha "Alpha at v1."
skill "$collection/skills/beta" beta "Beta exists only at v1."
skill "$collection/skills/CamelCase" camel-case "Case-preserving nested path."
skill "$collection/skills/general/ideation/naming" naming "Deeply nested Skill."
mkdir -p "$collection/skills/invalid"
printf '%s\n' '---' 'name: invalid' '---' '# Missing description' >"$collection/skills/invalid/SKILL.md"
commit_push "$collection" "collection v1"
git -C "$collection" tag v1.0.0
git -C "$collection" push origin v1.0.0 >/dev/null
rm -rf "$collection/skills/beta"
skill "$collection/skills/alpha" alpha "Alpha prerelease."
commit_push "$collection" "collection prerelease"
git -C "$collection" tag v1.1.0-beta.1
git -C "$collection" push origin v1.1.0-beta.1 >/dev/null
skill "$collection/skills/alpha" alpha "Alpha stable."
commit_push "$collection" "collection stable"
git -C "$collection" tag v1.1.0
git -C "$collection" push origin v1.1.0 >/dev/null

new_repo mixed
mixed="$work_root/mixed"
skill "$mixed/skills/alpha" alpha "Alpha v1."
skill "$mixed/skills/beta" beta "Beta v1."
commit_push "$mixed" "mixed v1"
git -C "$mixed" tag v1.0.0
git -C "$mixed" push origin v1.0.0 >/dev/null
skill "$mixed/skills/alpha" alpha "Alpha v2."
skill "$mixed/skills/beta" beta "Beta v2."
commit_push "$mixed" "mixed v2"
git -C "$mixed" tag v1.1.0
git -C "$mixed" push origin v1.1.0 >/dev/null

new_repo prerelease
prerelease="$work_root/prerelease"
skill "$prerelease/skills/preview" preview "Preview only."
commit_push "$prerelease" "preview"
git -C "$prerelease" tag v1.2.0-beta.2
git -C "$prerelease" push origin v1.2.0-beta.2 >/dev/null

new_repo untagged
untagged="$work_root/untagged"
skill "$untagged/skills/head" head-skill "Untagged default branch."
commit_push "$untagged" "untagged head"

new_repo tagged-ahead
tagged_ahead="$work_root/tagged-ahead"
skill "$tagged_ahead/skills/head" tagged-head-skill "Tagged base."
commit_push "$tagged_ahead" "tagged base"
git -C "$tagged_ahead" tag v1.0.0
git -C "$tagged_ahead" push origin v1.0.0 >/dev/null
skill "$tagged_ahead/skills/head" tagged-head-skill "Untagged descendant."
commit_push "$tagged_ahead" "untagged descendant"

new_repo movable
movable="$work_root/movable"
skill "$movable/skills/head" movable-head-skill "Movable C1."
commit_push "$movable" "movable C1"

new_repo duplicate
duplicate="$work_root/duplicate"
skill "$duplicate/one" shared "First shared name."
skill "$duplicate/two" shared "Second shared name."
commit_push "$duplicate" "duplicate names"
git -C "$duplicate" tag v1.0.0
git -C "$duplicate" push origin v1.0.0 >/dev/null

index=1
while [ "$index" -le 10 ]; do
  name="capacity-$index"
  new_repo "$name"
  capacity="$work_root/$name"
  skill "$capacity" "$name" "Capacity fixture $index."
  commit_push "$capacity" "capacity $index"
  git -C "$capacity" tag v1.0.0
  git -C "$capacity" push origin v1.0.0 >/dev/null
  index=$((index + 1))
done
