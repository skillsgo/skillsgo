#!/usr/bin/env node
/*
 * [INPUT]: Node.js process platform/architecture, optional npm dependency, and CLI arguments.
 * [OUTPUT]: Executes the matching native SkillsGo binary and mirrors its exit status.
 * [POS]: The npm entrypoint used by `npx skillsgo` and the global npm install.
 * [PROTOCOL]: Keep platform package names aligned with cli/npm/assemble.mjs.
 */

'use strict';

const { spawnSync } = require('node:child_process');

const PLATFORM_PACKAGES = new Map([
  ['darwin/arm64', 'skillsgo-darwin-arm64'],
  ['darwin/x64', 'skillsgo-darwin-x64'],
  ['linux/arm64', 'skillsgo-linux-arm64'],
  ['linux/x64', 'skillsgo-linux-x64'],
  ['win32/x64', 'skillsgo-win32-x64'],
]);

function fail(message, error) {
  process.stderr.write(`skillsgo: ${message}\n`);
  if (error && error.message) {
    process.stderr.write(`${error.message}\n`);
  }
  process.exit(1);
}

const platformKey = `${process.platform}/${process.arch}`;
const packageName = PLATFORM_PACKAGES.get(platformKey);

if (!packageName) {
  fail(
    `no native package is available for ${platformKey}; supported targets are ` +
      `${Array.from(PLATFORM_PACKAGES.keys()).join(', ')}`,
  );
}

let binaryPath;
try {
  binaryPath = require(packageName);
} catch (error) {
  fail(
    `the optional dependency ${packageName} is missing; reinstall ` +
      '`skillsgo` without --omit=optional or --ignore-optional',
    error,
  );
}

if (typeof binaryPath !== 'string' || binaryPath.length === 0) {
  fail(`the optional dependency ${packageName} did not provide a native binary path`);
}

const result = spawnSync(binaryPath, process.argv.slice(2), {
  stdio: 'inherit',
  windowsHide: false,
});

if (result.error) {
  fail(`could not start the native binary at ${binaryPath}`, result.error);
}

process.exit(typeof result.status === 'number' ? result.status : 1);
