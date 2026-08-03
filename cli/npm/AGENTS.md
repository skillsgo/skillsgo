# npm Distribution Package

This directory contains the source for the public `skillsgo` npm distribution.
The executable is still built by the Go CLI release pipeline. The Node launcher
selects the platform-specific optional dependency and forwards arguments and
exit status to the native executable.

## Files

- `bin/skillsgo.js` — cross-platform `npx skillsgo` launcher.
- `assemble.mjs` — turns CLI release archives into the main npm package and
  one optional package for each supported platform.
- `README.md` — package-manager installation notes.

Generated package manifests and tarballs are release artifacts and must not be
committed here.

## Contract

The public package name is unscoped: `skillsgo`. Platform packages are named
`skillsgo-<os>-<arch>` and are declared as optional dependencies so npm only
installs the package compatible with the current machine.
