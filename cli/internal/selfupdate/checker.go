/*
 * [INPUT]: Depends on the fixed SkillsGo CLI CDN, embedded Ed25519 public key, HTTP transport, Go platform identity, and semantic-version rules.
 * [OUTPUT]: Provides authenticated, bounded, platform-specific CLI release checks without mutating the installed executable.
 * [POS]: Serves as the trusted discovery boundary for installation-source-aware CLI self update behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package selfupdate

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"runtime"
	"strings"
	"time"

	"golang.org/x/mod/semver"
)

const (
	DefaultOrigin     = "https://cdn.skillsgo.ai"
	manifestSchema    = 1
	maxManifestBytes  = 256 * 1024
	maxSignatureBytes = 1024
	publicKeyBase64   = "nR7t3Jk4ngVlpWwA7GOnY0xF+OZgVXYEp8DWBrpYIBM="
)

type Artifact struct {
	URL    string `json:"url"`
	SHA256 string `json:"sha256"`
	Size   int64  `json:"size"`
}

type Manifest struct {
	SchemaVersion int                 `json:"schemaVersion"`
	Version       string              `json:"version"`
	PublishedAt   string              `json:"publishedAt"`
	Commit        string              `json:"commit"`
	Artifacts     map[string]Artifact `json:"artifacts"`
	GitHubRelease string              `json:"githubRelease,omitempty"`
}

type Result struct {
	SchemaVersion   int      `json:"schemaVersion"`
	CurrentVersion  string   `json:"currentVersion"`
	LatestVersion   string   `json:"latestVersion"`
	UpdateAvailable bool     `json:"updateAvailable"`
	Platform        string   `json:"platform"`
	Artifact        Artifact `json:"artifact"`
	Distribution    string   `json:"distribution"`
	UpgradeCommand  string   `json:"upgradeCommand,omitempty"`
}

type Checker struct {
	origin    *url.URL
	publicKey ed25519.PublicKey
	client    *http.Client
	goos      string
	goarch    string
}

func NewDefaultChecker() *Checker {
	key, err := base64.StdEncoding.DecodeString(publicKeyBase64)
	if err != nil || len(key) != ed25519.PublicKeySize {
		panic("invalid embedded CLI Manifest public key")
	}
	origin, _ := url.Parse(DefaultOrigin)
	return &Checker{origin: origin, publicKey: ed25519.PublicKey(key), client: secureHTTPClient(origin), goos: runtime.GOOS, goarch: runtime.GOARCH}
}

func NewChecker(origin string, publicKey ed25519.PublicKey, client *http.Client, goos, goarch string) (*Checker, error) {
	parsed, err := url.Parse(strings.TrimRight(origin, "/"))
	if err != nil || parsed.Scheme == "" || parsed.Host == "" || parsed.RawQuery != "" || parsed.Fragment != "" || parsed.Path != "" {
		return nil, fmt.Errorf("invalid CLI update origin")
	}
	if len(publicKey) != ed25519.PublicKeySize {
		return nil, fmt.Errorf("invalid CLI Manifest public key")
	}
	if client == nil {
		client = secureHTTPClient(parsed)
	}
	return &Checker{origin: parsed, publicKey: append(ed25519.PublicKey(nil), publicKey...), client: client, goos: goos, goarch: goarch}, nil
}

func secureHTTPClient(origin *url.URL) *http.Client {
	return &http.Client{
		Timeout: 15 * time.Second,
		CheckRedirect: func(request *http.Request, _ []*http.Request) error {
			if request.URL.Scheme != origin.Scheme || request.URL.Host != origin.Host {
				return fmt.Errorf("CLI update redirect left the trusted origin")
			}
			return nil
		},
	}
}

func (c *Checker) Check(ctx context.Context, currentVersion, distribution, requestedVersion string) (Result, error) {
	manifestPath := "/cli/stable/manifest.json"
	signaturePath := "/cli/stable/manifest.sig"
	if requestedVersion != "" {
		if !validVersion(requestedVersion) {
			return Result{}, fmt.Errorf("invalid requested CLI version %q", requestedVersion)
		}
		manifestPath = "/cli/versions/" + requestedVersion + "/manifest.json"
		signaturePath = "/cli/versions/" + requestedVersion + "/manifest.sig"
	}

	manifestBytes, err := c.read(ctx, manifestPath, maxManifestBytes)
	if err != nil {
		return Result{}, err
	}
	signature, err := c.read(ctx, signaturePath, maxSignatureBytes)
	if err != nil {
		return Result{}, err
	}
	if len(signature) != ed25519.SignatureSize || !ed25519.Verify(c.publicKey, manifestBytes, signature) {
		return Result{}, fmt.Errorf("CLI update Manifest signature is invalid")
	}

	var manifest Manifest
	decoder := json.NewDecoder(bytes.NewReader(manifestBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&manifest); err != nil || decoder.Decode(&struct{}{}) != io.EOF {
		return Result{}, fmt.Errorf("invalid CLI update Manifest")
	}
	if err := c.validateManifest(manifest, requestedVersion); err != nil {
		return Result{}, err
	}

	platform := c.goos + "_" + c.goarch
	artifact, ok := manifest.Artifacts[platform]
	if !ok {
		return Result{}, fmt.Errorf("CLI release %s does not support %s", manifest.Version, platform)
	}
	upgradeCommand := upgradeCommandFor(distribution)
	available := currentVersion == "dev" || !validVersion(currentVersion) || semver.Compare(manifest.Version, currentVersion) > 0
	return Result{SchemaVersion: 1, CurrentVersion: currentVersion, LatestVersion: manifest.Version, UpdateAvailable: available, Platform: platform, Artifact: artifact, Distribution: distribution, UpgradeCommand: upgradeCommand}, nil
}

func (c *Checker) read(ctx context.Context, path string, limit int64) ([]byte, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, c.origin.String()+path, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Accept", "application/octet-stream")
	response, err := c.client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("read CLI update metadata: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("CLI update metadata returned HTTP %d", response.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, limit+1))
	if err != nil {
		return nil, fmt.Errorf("read CLI update metadata: %w", err)
	}
	if int64(len(data)) > limit {
		return nil, fmt.Errorf("CLI update metadata exceeds the size limit")
	}
	return data, nil
}

func (c *Checker) validateManifest(manifest Manifest, requestedVersion string) error {
	if manifest.SchemaVersion != manifestSchema || !validVersion(manifest.Version) || strings.TrimSpace(manifest.Commit) == "" {
		return fmt.Errorf("invalid CLI update Manifest identity")
	}
	if requestedVersion != "" && manifest.Version != requestedVersion {
		return fmt.Errorf("CLI update Manifest version mismatch")
	}
	if _, err := time.Parse(time.RFC3339, manifest.PublishedAt); err != nil || len(manifest.Artifacts) == 0 {
		return fmt.Errorf("invalid CLI update Manifest publication")
	}
	for platform, artifact := range manifest.Artifacts {
		expectedName, ok := expectedArtifactName(platform, manifest.Version)
		if !ok || artifact.Size <= 0 || len(artifact.SHA256) != 64 {
			return fmt.Errorf("invalid CLI artifact metadata for %s", platform)
		}
		if _, err := hex.DecodeString(artifact.SHA256); err != nil {
			return fmt.Errorf("invalid CLI artifact digest for %s", platform)
		}
		artifactURL, err := url.Parse(artifact.URL)
		if err != nil || artifactURL.Scheme != c.origin.Scheme || artifactURL.Host != c.origin.Host || artifactURL.User != nil || artifactURL.RawQuery != "" || artifactURL.Fragment != "" || artifactURL.EscapedPath() != "/cli/versions/"+manifest.Version+"/"+expectedName {
			return fmt.Errorf("untrusted CLI artifact URL for %s", platform)
		}
	}
	if manifest.GitHubRelease != "" && manifest.GitHubRelease != "https://github.com/skillsgo/skillsgo/releases/tag/cli/"+manifest.Version {
		return fmt.Errorf("untrusted CLI GitHub Release URL")
	}
	return nil
}

func expectedArtifactName(platform, version string) (string, bool) {
	extension := ".tar.gz"
	switch platform {
	case "darwin_arm64", "darwin_amd64", "linux_arm64", "linux_amd64":
	case "windows_amd64":
		extension = ".zip"
	default:
		return "", false
	}
	return "skillsgo_" + strings.TrimPrefix(version, "v") + "_" + platform + extension, true
}

func validVersion(version string) bool {
	return semver.IsValid(version) && semver.Canonical(version) == version
}

func upgradeCommandFor(distribution string) string {
	switch distribution {
	case "bundled":
		return "Update the SkillsGo App"
	case "homebrew":
		return "brew upgrade skillsgo"
	case "winget":
		return "winget upgrade SkillsGo.CLI"
	case "npm":
		return "npm install --global @skillsgo/cli@latest"
	case "npx":
		return "npx @skillsgo/cli@latest"
	case "go-install":
		return "go install github.com/skillsgo/skillsgo/cli/cmd/skillsgo@latest"
	default:
		return ""
	}
}
