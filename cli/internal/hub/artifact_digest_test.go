/*
 * [INPUT]: Uses in-memory immutable Skill ZIP archives and declared Hub Content Digests.
 * [OUTPUT]: Specifies golden, compression-independent digest computation and mismatch rejection at the CLI Hub boundary.
 * [POS]: Serves as executable integrity coverage for artifacts before Store persistence or installation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"archive/zip"
	"bytes"
	"testing"
)

func TestVerifyContentDigestBindsInfoToExactArtifactFiles(t *testing.T) {
	skillID, version := "github.com/example/skills/-/demo", "v1"
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	entry, err := writer.Create(skillID + "@" + version + "/SKILL.md")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := entry.Write([]byte("# Demo\n")); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}

	digest, err := ContentDigest(buffer.Bytes(), skillID, version)
	if err != nil {
		t.Fatal(err)
	}
	if digest != "sha256:bf005aa0d71df7bbcdc3bbd01138efd6274f8cef648cf74a2a17528bfaa54399" {
		t.Fatalf("Hub digest framing changed: %s", digest)
	}
	if err := VerifyContentDigest(buffer.Bytes(), skillID, version, digest); err != nil {
		t.Fatalf("expected matching digest: %v", err)
	}
	if err := VerifyContentDigest(buffer.Bytes(), skillID, version, "sha256:different"); err == nil {
		t.Fatal("expected mismatched artifact rejection")
	}
}

func TestValidateAssessedInfoRejectsHostileResolvedVersion(t *testing.T) {
	info := Info{
		Version: "v1?download=1", Risk: RiskLow,
		ContentDigest: "sha256:bf005aa0d71df7bbcdc3bbd01138efd6274f8cef648cf74a2a17528bfaa54399",
	}
	if err := validateAssessedInfo("github.com/example/skills/-/demo", "main", info); err == nil {
		t.Fatal("expected hostile Hub version rejection")
	}
}
