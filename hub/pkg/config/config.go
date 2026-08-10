/*
 * [INPUT]: Depends on YAML, environment decoding, Hub defaults, validation, and nested storage, database, presentation, and authentication settings.
 * [OUTPUT]: Provides validated Hub configuration including authentication, cache policy, optional public image-proxy discovery, first-class Cloudflare R2 storage, task execution with automatic Package latest synchronization, and optional translation.
 * [POS]: Serves as the Hub configuration composition and validation source in the config package.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import (
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"

	"github.com/go-playground/validator/v10"
	"github.com/kelseyhightower/envconfig"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/presentation"
	"go.yaml.in/yaml/v3"
)

const defaultConfigFile = "skillsgo-hub.yaml"

// Config provides configuration values for all components.
type Config struct {
	TimeoutConf

	Environment             string    `envconfig:"SKILLSGO_HUB_ENVIRONMENT" validate:"required"`
	SkillCacheDir           string    `ignored:"true"`
	RepositoryCacheTTL      int       `envconfig:"SKILLSGO_HUB_REPOSITORY_CACHE_TTL" validate:"min=0"`
	RepositoryCacheMaxBytes int64     `envconfig:"SKILLSGO_HUB_REPOSITORY_CACHE_MAX_BYTES" validate:"min=0"`
	LogLevel                string    `envconfig:"SKILLSGO_HUB_LOG_LEVEL"               validate:"required"`
	LogFormat               string    `envconfig:"SKILLSGO_HUB_LOG_FORMAT"              validate:"oneof='' 'json' 'plain'"`
	CloudRuntime            string    `envconfig:"SKILLSGO_HUB_CLOUD_RUNTIME"           validate:"required_without=LogFormat"`
	EnablePprof             bool      `envconfig:"SKILLSGO_HUB_ENABLE_PPROF"`
	PprofPort               string    `envconfig:"SKILLSGO_HUB_PPROF_PORT"`
	FilterFile              string    `envconfig:"SKILLSGO_HUB_FILTER_FILE"`
	TraceExporterURL        string    `envconfig:"SKILLSGO_HUB_TRACE_EXPORTER_URL"`
	TraceExporter           string    `envconfig:"SKILLSGO_HUB_TRACE_EXPORTER"`
	TraceSamplingFraction   float64   `envconfig:"SKILLSGO_HUB_TRACE_SAMPLING_FRACTION"`
	StatsExporter           string    `envconfig:"SKILLSGO_HUB_STATS_EXPORTER"`
	StorageType             string    `envconfig:"SKILLSGO_HUB_STORAGE_TYPE"            validate:"required"`
	Port                    string    `envconfig:"SKILLSGO_HUB_PORT"`
	UnixSocket              string    `envconfig:"SKILLSGO_HUB_UNIX_SOCKET"`
	BasicAuthUser           string    `envconfig:"SKILLSGO_HUB_BASIC_AUTH_USER"`
	BasicAuthPass           string    `envconfig:"SKILLSGO_HUB_BASIC_AUTH_PASS"`
	AdminAuthUser           string    `envconfig:"SKILLSGO_HUB_ADMIN_AUTH_USER"`
	AdminAuthPass           string    `envconfig:"SKILLSGO_HUB_ADMIN_AUTH_PASS"`
	HomeTemplatePath        string    `envconfig:"SKILLSGO_HUB_HOME_TEMPLATE_PATH"`
	ForceSSL                bool      `envconfig:"SKILLSGO_HUB_FORCE_SSL"`
	ValidatorHook           string    `envconfig:"SKILLSGO_HUB_PROXY_VALIDATOR"`
	PathPrefix              string    `envconfig:"SKILLSGO_HUB_PATH_PREFIX"`
	GithubTokens            TokenList `envconfig:"SKILLSGO_HUB_GITHUB_TOKENS"`
	TLSCertFile             string    `envconfig:"SKILLSGO_HUB_TLSCERT_FILE"`
	TLSKeyFile              string    `envconfig:"SKILLSGO_HUB_TLSKEY_FILE"`
	ArtifactOrigin          string    `envconfig:"SKILLSGO_HUB_ARTIFACT_ORIGIN"`
	ImageProxyOrigin        string    `envconfig:"SKILLSGO_HUB_IMAGE_PROXY_ORIGIN"`
	NetworkMode             string    `envconfig:"SKILLSGO_HUB_NETWORK_MODE"            validate:"oneof=strict offline fallback"`
	RobotsFile              string    `envconfig:"SKILLSGO_HUB_ROBOTS_FILE"`
	ShutdownTimeout         int       `envconfig:"SKILLSGO_HUB_SHUTDOWN_TIMEOUT"        validate:"min=0"`
	Storage                 *Storage
	Database                *DatabaseConfig
	TaskQueue               *TaskQueueConfig
	LLM                     *LLMConfig
}

// EnvList is a list of key-value environment
// variables that are passed to the Go command.
type EnvList []string

// TokenList supports YAML sequences and comma, semicolon, or newline-delimited
// environment overrides.
type TokenList []string

// Decode implements envconfig.Decoder for SKILLSGO_HUB_GITHUB_TOKENS.
func (tokens *TokenList) Decode(value string) error {
	decoded := strings.FieldsFunc(value, func(r rune) bool {
		return r == ',' || r == ';' || r == '\n' || r == '\r'
	})
	*tokens = (*tokens)[:0]
	for _, token := range decoded {
		if trimmed := strings.TrimSpace(token); trimmed != "" {
			*tokens = append(*tokens, trimmed)
		}
	}
	return nil
}

// HasKey returns whether a key-value entry
// is present by only checking the left of
// key=value.
func (el EnvList) HasKey(key string) bool {
	for _, env := range el {
		if strings.HasPrefix(env, key+"=") {
			return true
		}
	}
	return false
}

// Add adds a key=value entry to the environment
// list.
func (el *EnvList) Add(key, value string) {
	*el = append(*el, key+"="+value)
}

// Decode implements envconfig.Decoder. Please see the below link for more information on
// that interface:
//
// https://github.com/kelseyhightower/envconfig#custom-decoders
//
// We are doing this to allow for very long lists of assignments to be set inside of
// a single environment variable. For example:
//
//	SKILLSGO_HUB_GO_BINARY_ENV_VARS="GOPRIVATE=*.corp.example.com,rsc.io/private; GOPROXY=direct"
//
// See the below link for more information:
// https://github.com/skillsgo/skillsgo/hub/issues/1404
func (el *EnvList) Decode(value string) error {
	if value == "" {
		return nil
	}
	*el = EnvList{} // env vars must override config file
	assignments := strings.SplitSeq(value, ";")
	for assignment := range assignments {
		*el = append(*el, strings.TrimSpace(assignment))
	}
	return el.Validate()
}

// Validate validates that all strings inside the
// list are of the key=value format.
func (el EnvList) Validate() error {
	const op errors.Op = "EnvList.Validate"
	for _, env := range el {
		// some strings can have multiple "=", such as GODEBUG=netdns=cgo
		if strings.Count(env, "=") < 1 {
			return errors.E(op, fmt.Errorf("incorrect env format: %v", env))
		}
	}
	return nil
}

// Load loads the config from a file.
// If file is not present returns default config.
func Load(configFile string) (*Config, error) {
	// User explicitly specified a config file
	if configFile != "" {
		return ParseConfigFile(configFile)
	}

	// There is a config in the current directory
	if fi, err := os.Stat(defaultConfigFile); err == nil {
		return ParseConfigFile(fi.Name())
	}

	// Use default values
	log.Println("Running dev mode with default settings, consult config when you're ready to run in production")
	cfg := defaultConfig()
	return cfg, envOverride(cfg)
}

func defaultConfig() *Config {
	return &Config{
		Environment:             "development",
		GithubTokens:            TokenList{},
		RepositoryCacheTTL:      604800,
		RepositoryCacheMaxBytes: 10 << 30,
		LogLevel:                "debug",
		LogFormat:               "plain",
		CloudRuntime:            "none",
		EnablePprof:             false,
		PprofPort:               ":3001",
		StatsExporter:           "prometheus",
		TimeoutConf:             TimeoutConf{Timeout: 300},
		HomeTemplatePath:        "/var/lib/skillsgo/home.html",
		StorageType:             "disk",
		Port:                    ":3000",
		TraceExporterURL:        "http://localhost:4317",
		TraceSamplingFraction:   1.0,
		ArtifactOrigin:          "",
		ImageProxyOrigin:        "https://images.skillsgo.ai",
		NetworkMode:             "strict",
		RobotsFile:              "robots.txt",
		ShutdownTimeout:         60,
		Storage: &Storage{
			Disk: &DiskConfig{},
		},
		Database: &DatabaseConfig{
			DSN:                    "postgres://skillsgo:skillsgo-dev@localhost:5432/skillsgo_hub?sslmode=disable",
			Schema:                 DefaultDatabaseSchema,
			ExtensionSchema:        DefaultDatabaseSchema,
			MaxOpenConns:           20,
			BackgroundMaxOpenConns: 40,
			ConnMaxLifetime:        1800,
		},
		TaskQueue: &TaskQueueConfig{MaxWorkers: 10, FetchPollSeconds: 10, RepositoryMaterializerCapacity: 8, PackageLatestSyncIntervalSeconds: 3600},
		LLM: &LLMConfig{
			BaseURL: "https://api.deepseek.com", Model: "deepseek-v4-flash",
			TranslationLangs: []string{"en", "zh-Hans-CN", "zh-Hant-TW", "zh-Hant-HK", "ja", "ko", "fr", "de", "it", "es", "pt-BR", "ru", "ar", "hi", "id", "tr", "nl", "pl", "th", "vi", "ms", "sv", "uk"}, TranslationInterval: 900,
			TranslationBatch: 100, TranslationTimeZone: "UTC",
			DescriptionPromptVersion: "description-v7", DocumentPromptVersion: "skill-document-v9",
		},
	}
}

// BasicAuth returns BasicAuthUser and BasicAuthPassword
// and ok if neither of them are empty.
func (c *Config) BasicAuth() (user, pass string, ok bool) {
	user = c.BasicAuthUser
	pass = c.BasicAuthPass
	ok = user != "" && pass != ""
	return user, pass, ok
}

// AdminAuth returns the credentials scoped to Hub administration routes.
func (c *Config) AdminAuth() (user, pass string, ok bool) {
	user = c.AdminAuthUser
	pass = c.AdminAuthPass
	ok = user != "" && pass != ""
	return user, pass, ok
}

// GitHubTokens returns the configured token pool in stable, deduplicated order.
func (c *Config) GitHubTokens() []string {
	seen := make(map[string]struct{}, len(c.GithubTokens))
	tokens := make([]string, 0, len(c.GithubTokens))
	for _, candidate := range c.GithubTokens {
		token := strings.TrimSpace(candidate)
		if token == "" {
			continue
		}
		if _, exists := seen[token]; exists {
			continue
		}
		seen[token] = struct{}{}
		tokens = append(tokens, token)
	}
	if len(tokens) == 0 {
		return nil
	}
	return tokens
}

// FilterOff returns true if the FilterFile is empty.
func (c *Config) FilterOff() bool {
	return c.FilterFile == ""
}

// ParseConfigFile parses the given file into an athens config struct.
func ParseConfigFile(configFile string) (*Config, error) {
	// Always start from a default config.
	config := defaultConfig()

	// attempt to read the given config file
	contents, err := os.ReadFile(configFile)
	if err != nil {
		return nil, err
	}
	if err := decodeYAML(contents, config); err != nil {
		return nil, err
	}

	// override values with environment variables if specified
	if err := envOverride(config); err != nil {
		return nil, err
	}

	// Check file perms from config
	if config.Environment == "production" {
		if err := checkFilePerms(configFile, config.FilterFile); err != nil {
			return nil, err
		}
	}

	// validate all required fields have been populated
	if err := validateConfig(*config); err != nil {
		return nil, err
	}
	return config, nil
}

func decodeYAML(contents []byte, destination any) error {
	var document any
	if err := yaml.Unmarshal(contents, &document); err != nil {
		return err
	}
	normalized, err := json.Marshal(document)
	if err != nil {
		return err
	}
	return json.Unmarshal(normalized, destination)
}

// envOverride uses Environment variables to override unspecified properties.
func envOverride(config *Config) error {
	const defaultPort = ":3000"
	err := envconfig.Process("", config)
	if err != nil {
		return err
	}
	if config.StorageType == "r2" {
		if config.Storage == nil {
			config.Storage = &Storage{}
		}
		if config.Storage.R2 == nil {
			config.Storage.R2 = &R2Config{}
			if err := envconfig.Process("", config); err != nil {
				return err
			}
		}
	}
	config.SkillCacheDir, err = resolveHubCacheDir(config.SkillCacheDir)
	if err != nil {
		return err
	}
	if config.Database == nil {
		config.Database = &DatabaseConfig{}
	}
	if config.Database.DSN == "" {
		config.Database.DSN = "postgres://skillsgo:skillsgo-dev@localhost:5432/skillsgo_hub?sslmode=disable"
	}
	if config.Database.Schema == "" {
		config.Database.Schema = DefaultDatabaseSchema
	}
	if config.Database.ExtensionSchema == "" {
		config.Database.ExtensionSchema = DefaultDatabaseSchema
	}
	if config.Database.MaxOpenConns == 0 {
		config.Database.MaxOpenConns = 20
	}
	if config.Database.BackgroundMaxOpenConns == 0 {
		config.Database.BackgroundMaxOpenConns = 40
	}
	if config.Database.ConnMaxLifetime == 0 {
		config.Database.ConnMaxLifetime = 1800
	}
	if config.LLM == nil {
		config.LLM = defaultConfig().LLM
	}
	seenLangs := make(map[string]bool, len(config.LLM.TranslationLangs))
	canonicalLangs := make([]string, 0, len(config.LLM.TranslationLangs))
	for _, lang := range config.LLM.TranslationLangs {
		canonical, canonicalErr := presentation.CanonicalLang(lang)
		if canonicalErr != nil {
			return canonicalErr
		}
		if !seenLangs[canonical] {
			seenLangs[canonical] = true
			canonicalLangs = append(canonicalLangs, canonical)
		}
	}
	config.LLM.TranslationLangs = canonicalLangs
	if config.StorageType == "disk" {
		if config.Storage == nil {
			config.Storage = &Storage{}
		}
		if config.Storage.Disk == nil {
			config.Storage.Disk = &DiskConfig{}
		}
		config.Storage.Disk.RootPath, err = resolveHubArtifactDir(config.Storage.Disk.RootPath)
		if err != nil {
			return err
		}
	}
	if config.Port == "" {
		config.Port = defaultPort
	}
	config.Port = ensurePortFormat(config.Port)
	if err := validateHTTPOrigin("SKILLSGO_HUB_ARTIFACT_ORIGIN", config.ArtifactOrigin, true); err != nil {
		return err
	}
	return validateHTTPOrigin("SKILLSGO_HUB_IMAGE_PROXY_ORIGIN", config.ImageProxyOrigin, false)
}

func ensurePortFormat(s string) string {
	if _, err := strconv.Atoi(s); err == nil {
		return ":" + s
	}
	return s
}

func validateConfig(config Config) error {
	validate := validator.New()
	err := validate.StructExcept(config, "Storage", "Database", "TaskQueue")
	if err != nil {
		return err
	}
	err = validateStorage(validate, config.StorageType, config.Storage)
	if err != nil {
		return err
	}
	if err := validateDatabase(validate, config.Database); err != nil {
		return err
	}
	if err := validateCredentialPair("global Basic Auth", config.BasicAuthUser, config.BasicAuthPass); err != nil {
		return err
	}
	if err := validateCredentialPair("Admin Basic Auth", config.AdminAuthUser, config.AdminAuthPass); err != nil {
		return err
	}
	if err := validateHTTPOrigin("SKILLSGO_HUB_ARTIFACT_ORIGIN", config.ArtifactOrigin, true); err != nil {
		return err
	}
	if err := validateHTTPOrigin("SKILLSGO_HUB_IMAGE_PROXY_ORIGIN", config.ImageProxyOrigin, false); err != nil {
		return err
	}
	if config.TaskQueue == nil {
		return fmt.Errorf("task queue configuration is required")
	}
	if err := validate.Struct(config.TaskQueue); err != nil {
		return err
	}
	return validate.Struct(config.LLM)
}

func validateArtifactOrigin(origin string) error {
	return validateHTTPOrigin("SKILLSGO_HUB_ARTIFACT_ORIGIN", origin, true)
}

func validateHTTPOrigin(name, origin string, allowPath bool) error {
	if strings.TrimSpace(origin) == "" {
		return nil
	}
	parsed, err := url.Parse(origin)
	if err != nil || parsed.Host == "" || parsed.User != nil || parsed.RawQuery != "" || parsed.Fragment != "" ||
		(parsed.Scheme != "http" && parsed.Scheme != "https") || (!allowPath && parsed.Path != "") {
		return fmt.Errorf("%s must be an absolute HTTP(S) URL without credentials, query, fragment%s", name, map[bool]string{true: "", false: ", or path"}[allowPath])
	}
	return nil
}

func validateCredentialPair(name, user, pass string) error {
	if (user == "") != (pass == "") {
		return fmt.Errorf("%s user and password must be configured together", name)
	}
	return nil
}

func validateDatabase(validate *validator.Validate, database *DatabaseConfig) error {
	if database == nil {
		return fmt.Errorf("database configuration is required")
	}
	if err := validate.Struct(database); err != nil {
		return err
	}
	if database.DSN == "" {
		return fmt.Errorf("database DSN is required")
	}
	if !ValidDatabaseSchema(database.Schema) {
		return fmt.Errorf("database schema must be a lower-case PostgreSQL identifier")
	}
	if !ValidDatabaseSchema(database.ExtensionSchema) {
		return fmt.Errorf("database extension schema must be a lower-case PostgreSQL identifier")
	}
	return nil
}

func validateStorage(validate *validator.Validate, storageType string, config *Storage) error {
	switch storageType {
	case "memory":
		return nil
	case "disk":
		return validate.Struct(config.Disk)
	case "gcp":
		return validate.Struct(config.GCP)
	case "s3":
		return validate.Struct(config.S3)
	case "r2":
		return validate.Struct(config.R2)
	case "azureblob":
		return validate.Struct(config.AzureBlob)
	default:
		return fmt.Errorf("storage type %q is unknown", storageType)
	}
}

// GetConf accepts the path to a file, constructs an absolute path to the file,
// and attempts to parse it into a Config struct.
func GetConf(path string) (*Config, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("unable to construct absolute path to test config file")
	}
	conf, err := ParseConfigFile(absPath)
	if err != nil {
		return nil, fmt.Errorf("unable to parse test config file: %w", err)
	}
	return conf, nil
}

// checkFilePerms given a list of files.
func checkFilePerms(files ...string) error {
	const op = "config.checkFilePerms"

	for _, f := range files {
		if f == "" {
			continue
		}

		// TODO: Do not ignore errors when a file is not found
		// There is a subtle bug in the filter module which ignores the filter file if it does not find it.
		// This check can be removed once that has been fixed
		fInfo, err := os.Stat(f)
		if err != nil {
			continue
		}

		// Assume unix based system (MacOS and Linux)
		// the bit mask is calculated using the umask command which tells which permissions
		// should not be allowed for a particular user, group or world
		if fInfo.Mode()&0o033 != 0 && runtime.GOOS != "windows" {
			return errors.E(op, f+" should have at most rwx,-, - (bit mask 077) as permission")
		}
	}

	return nil
}
