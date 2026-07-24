# Security Policy

## Supported Versions

SkillsGo has not published its first stable release. Until a stable support policy is announced, security fixes target the latest commit on `main` and, once releases begin, the latest release of each actively developed release unit. Pre-release builds may change without backward-compatibility guarantees.

## Report a Vulnerability

Use GitHub's [private vulnerability reporting](https://github.com/skillsgo/skillsgo/security/advisories/new). Do not open a public issue, discussion, or pull request for an undisclosed vulnerability.

Include, when available:

- the affected App, CLI, Hub, Protocol, Web, or release version;
- impact and the security boundary that was crossed;
- minimal reproduction steps or a proof of concept;
- required permissions and environmental assumptions;
- suggested mitigations;
- whether the issue is already public or under active exploitation.

Remove unrelated personal data, credentials, tokens, and private source content. The maintainers will acknowledge a complete report as soon as practical, normally within seven days, and will coordinate validation, remediation, credit, and disclosure through the private advisory.

## Scope Guidance

Security-sensitive SkillsGo behavior includes:

- Repository identity, immutable version resolution, artifact integrity, and publication;
- archive and portable-path validation;
- local Vendor and Agent Projection writes, conflict preservation, and scope isolation;
- authentication and authorization for Hub administration;
- App-to-CLI machine contracts and command execution boundaries;
- release artifacts, update delivery, credentials, and build provenance.

A third-party Skill containing unsafe or malicious instructions is not automatically a vulnerability in SkillsGo. It may become one when SkillsGo violates a documented trust boundary—for example, by misrepresenting identity or integrity, bypassing required review, writing outside an authorized target, exposing credentials, or executing content contrary to the product contract.

## Disclosure

Please allow maintainers reasonable time to investigate and release a fix before public disclosure. We will aim to keep reporters informed when the assessment changes or a remediation milestone is reached. We may publish a GitHub Security Advisory and request a CVE when the impact warrants it.
