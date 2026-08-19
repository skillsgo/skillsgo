#!/usr/bin/env node
/*
 * [INPUT]: CLI release archives and a semantic version.
 * [OUTPUT]: npm package directories and tarballs for the main launcher and supported native targets.
 * [POS]: Release-only assembler; generated files are uploaded or published by CI and are not committed.
 * [PROTOCOL]: Archive names must match scripts/build-cli-release.sh.
 */

import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '../..');

const TARGETS = [
  { goos: 'darwin', goarch: 'arm64', packageName: 'skillsgo-darwin-arm64', archiveExt: 'tar.gz', binary: 'skillsgo' },
  { goos: 'darwin', goarch: 'amd64', packageName: 'skillsgo-darwin-x64', archiveExt: 'tar.gz', binary: 'skillsgo' },
  { goos: 'linux', goarch: 'arm64', packageName: 'skillsgo-linux-arm64', archiveExt: 'tar.gz', binary: 'skillsgo' },
  { goos: 'linux', goarch: 'amd64', packageName: 'skillsgo-linux-x64', archiveExt: 'tar.gz', binary: 'skillsgo' },
  { goos: 'windows', goarch: 'amd64', packageName: 'skillsgo-windows-x64', archiveExt: 'zip', binary: 'skillsgo.exe' },
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

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { stdio: 'inherit', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} exited with status ${result.status}`);
}

function writeJson(path, value) {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function packageVersion(value) {
  const normalized = value.replace(/^v/, '');
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(normalized)) {
    throw new Error(`version must be semver-compatible, received ${value}`);
  }
  return normalized;
}

function archiveFor(artifactsDirectory, version, target) {
  const base = `skillsgo_${version}_${target.goos}_${target.goarch}`;
  return join(artifactsDirectory, `${base}.${target.archiveExt}`);
}

function extractBinary(archivePath, target, directory) {
  mkdirSync(directory, { recursive: true });
  if (target.archiveExt === 'zip') {
    run('unzip', ['-q', archivePath, '-d', directory]);
  } else {
    run('tar', ['-xzf', archivePath, '-C', directory]);
  }

  const expectedDirectory = join(directory, `skillsgo_${packageVersion(versionFromArchive(archivePath))}_${target.goos}_${target.goarch}`);
  const candidateDirectories = [expectedDirectory, ...readdirSync(directory).map((name) => join(directory, name))];
  for (const candidate of candidateDirectories) {
    const binary = join(candidate, target.binary);
    if (existsSync(binary)) return binary;
  }
  throw new Error(`could not find ${target.binary} in ${archivePath}`);
}

function versionFromArchive(archivePath) {
  const fileName = archivePath.split('/').pop() ?? '';
  const match = fileName.match(/^skillsgo_(.+)_(darwin|linux|windows)_(amd64|arm64)\.(?:tar\.gz|zip)$/);
  if (!match) throw new Error(`unexpected CLI archive name: ${fileName}`);
  return match[1];
}

function makePlatformPackage(outputDirectory, version, target, binarySource) {
  const packageDirectory = join(outputDirectory, target.packageName);
  const binaryDirectory = join(packageDirectory, 'bin');
  mkdirSync(binaryDirectory, { recursive: true });
  cpSync(binarySource, join(binaryDirectory, target.binary));
  if (target.binary !== 'skillsgo.exe') run('chmod', ['0755', join(binaryDirectory, target.binary)]);

  writeJson(join(packageDirectory, 'package.json'), {
    name: target.packageName,
    version,
    description: `SkillsGo native binary for ${target.goos}/${target.goarch}`,
    main: 'index.js',
    files: ['bin', 'index.js', 'LICENSE'],
    os: [target.goos === 'windows' ? 'win32' : target.goos],
    cpu: [target.goarch === 'amd64' ? 'x64' : target.goarch],
    license: 'Apache-2.0',
    repository: { type: 'git', url: 'https://github.com/skillsgo/skillsgo.git' },
  });
  writeFileSync(
    join(packageDirectory, 'index.js'),
    `module.exports = require('node:path').join(__dirname, 'bin', ${JSON.stringify(target.binary)});\n`,
  );
  cpSync(join(repositoryRoot, 'LICENSE'), join(packageDirectory, 'LICENSE'));
  return packageDirectory;
}

function makeMainPackage(outputDirectory, version, platformPackages) {
  const packageDirectory = join(outputDirectory, 'skillsgo');
  mkdirSync(join(packageDirectory, 'bin'), { recursive: true });
  cpSync(join(scriptDirectory, 'bin/skillsgo.js'), join(packageDirectory, 'bin/skillsgo.js'));
  cpSync(join(scriptDirectory, 'README.md'), join(packageDirectory, 'README.md'));
  cpSync(join(repositoryRoot, 'LICENSE'), join(packageDirectory, 'LICENSE'));
  writeJson(join(packageDirectory, 'package.json'), {
    name: 'skillsgo',
    version,
    description: 'SkillsGo command-line interface',
    bin: { skillsgo: 'bin/skillsgo.js' },
    files: ['bin', 'README.md', 'LICENSE'],
    optionalDependencies: Object.fromEntries(platformPackages.map((name) => [name, version])),
    engines: { node: '>=18' },
    license: 'Apache-2.0',
    repository: { type: 'git', url: 'https://github.com/skillsgo/skillsgo.git' },
  });
  return packageDirectory;
}

function pack(packageDirectory, outputDirectory) {
  run('npm', ['pack', packageDirectory, '--pack-destination', outputDirectory]);
}

const version = packageVersion(argument('--version'));
const artifactsDirectory = resolve(argument('--artifacts'));
const outputDirectory = resolve(argument('--output'));

rmSync(outputDirectory, { recursive: true, force: true });
mkdirSync(outputDirectory, { recursive: true });
const temporaryDirectory = join(outputDirectory, '.extract');
mkdirSync(temporaryDirectory, { recursive: true });

const platformDirectories = [];
for (const target of TARGETS) {
  const archivePath = archiveFor(artifactsDirectory, version, target);
  if (!existsSync(archivePath)) throw new Error(`missing release archive: ${archivePath}`);
  const extractionDirectory = join(temporaryDirectory, target.packageName);
  const binarySource = extractBinary(archivePath, target, extractionDirectory);
  platformDirectories.push(makePlatformPackage(outputDirectory, version, target, binarySource));
}

const mainDirectory = makeMainPackage(outputDirectory, version, TARGETS.map((target) => target.packageName));
for (const packageDirectory of [...platformDirectories, mainDirectory]) pack(packageDirectory, outputDirectory);

rmSync(temporaryDirectory, { recursive: true, force: true });
const packages = readdirSync(outputDirectory).filter((name) => name.endsWith('.tgz')).sort();
console.log(`assembled ${packages.length} npm packages`);
for (const packageName of packages) console.log(`${packageName} ${sha256(join(outputDirectory, packageName))}`);
