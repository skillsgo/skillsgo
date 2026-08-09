#!/usr/bin/env node
/*
 * [INPUT]: A CLI release version, architecture-specific archives, and an optional immutable download base URL.
 * [OUTPUT]: A Homebrew Formula with macOS and Linux arm64/x86_64 URLs and SHA-256 digests.
 * [POS]: Produces the formula consumed by the SkillsGo Homebrew tap.
 * [PROTOCOL]: Archive names must match scripts/build-cli-release.sh.
 */

import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const TARGETS = [
  { goos: 'darwin', goarch: 'arm64' },
  { goos: 'darwin', goarch: 'amd64' },
  { goos: 'linux', goarch: 'arm64' },
  { goos: 'linux', goarch: 'amd64' },
];

function argument(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index === -1) {
    if (fallback !== undefined) return fallback;
    throw new Error(`missing required argument ${name}`);
  }
  const value = process.argv[index + 1];
  if (!value || value.startsWith('--')) throw new Error(`argument ${name} needs a value`);
  return value;
}

function packageVersion(value) {
  const normalized = value.replace(/^v/, '');
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(normalized)) {
    throw new Error(`version must be semver-compatible, received ${value}`);
  }
  return normalized;
}

function archivePath(artifactsDirectory, version, target) {
  return join(artifactsDirectory, `skillsgo_${version}_${target.goos}_${target.goarch}.tar.gz`);
}

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function verifyFormulaSyntax(path) {
  const result = spawnSync('ruby', ['-c', path], { encoding: 'utf8' });
  if (result.error) return;
  if (result.status !== 0) throw new Error(`generated Homebrew Formula is not valid Ruby: ${result.stderr}`);
}

const version = packageVersion(argument('--version'));
const artifactsDirectory = resolve(argument('--artifacts'));
const outputPath = resolve(argument('--output'));
const baseUrl = argument(
  '--base-url',
  `https://github.com/skillsgo/skillsgo/releases/download/cli/v${version}`,
).replace(/\/$/, '');

const values = new Map();
for (const target of TARGETS) {
  const path = archivePath(artifactsDirectory, version, target);
  if (!existsSync(path)) throw new Error(`missing release archive: ${path}`);
  values.set(`${target.goos}/${target.goarch}`, {
    url: `${baseUrl}/skillsgo_${version}_${target.goos}_${target.goarch}.tar.gz`,
    sha256: sha256(path),
  });
}

const formula = `class Skillsgo < Formula
  desc "SkillsGo command-line interface"
  homepage "https://github.com/skillsgo/skillsgo"
  version "${version}"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "${values.get('darwin/arm64').url}"
      sha256 "${values.get('darwin/arm64').sha256}"
    else
      url "${values.get('darwin/amd64').url}"
      sha256 "${values.get('darwin/amd64').sha256}"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "${values.get('linux/arm64').url}"
      sha256 "${values.get('linux/arm64').sha256}"
    else
      url "${values.get('linux/amd64').url}"
      sha256 "${values.get('linux/amd64').sha256}"
    end
  end

  def install
    binary = Dir["*/skillsgo"].first || "skillsgo"
    bin.install binary
  end

  test do
    output = shell_output("#{bin}/skillsgo version --output json")
    assert_match version.to_s, output
  end
end
`;

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, formula);
verifyFormulaSyntax(outputPath);
console.log(`generated ${outputPath}`);
