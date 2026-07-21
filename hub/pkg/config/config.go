/*
 * [INPUT]: Depends on TOML, environment decoding, Hub defaults, validation, and nested storage, database, presentation, and authentication settings.
 * [OUTPUT]: Provides validated Hub configuration including GitHub authentication, optional translation, and skills.sh synchronization.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"

	"github.com/BurntSushi/toml"
	"github.com/go-playground/validator/v10"
	"github.com/kelseyhightower/envconfig"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/presentation"
)

const defaultConfigFile = "athens.toml"

// Config provides configuration values for all components.
type Config struct {
	TimeoutConf

	Environment           string    `envconfig:"SKILLSGO_HUB_ENVIRONMENT" validate:"required"`
	SkillFetchWorkers     int       `envconfig:"SKILLSGO_HUB_SKILL_FETCH_WORKERS"           validate:"required"`
	SkillCacheDir         string    `ignored:"true"`
	ProtocolWorkers       int       `envconfig:"SKILLSGO_HUB_PROTOCOL_WORKERS"        validate:"required"`
	LogLevel              string    `envconfig:"SKILLSGO_HUB_LOG_LEVEL"               validate:"required"`
	LogFormat             string    `envconfig:"SKILLSGO_HUB_LOG_FORMAT"              validate:"oneof='' 'json' 'plain'"`
	CloudRuntime          string    `envconfig:"SKILLSGO_HUB_CLOUD_RUNTIME"           validate:"required_without=LogFormat"`
	EnablePprof           bool      `envconfig:"SKILLSGO_HUB_ENABLE_PPROF"`
	PprofPort             string    `envconfig:"SKILLSGO_HUB_PPROF_PORT"`
	FilterFile            string    `envconfig:"SKILLSGO_HUB_FILTER_FILE"`
	TraceExporterURL      string    `envconfig:"SKILLSGO_HUB_TRACE_EXPORTER_URL"`
	TraceExporter         string    `envconfig:"SKILLSGO_HUB_TRACE_EXPORTER"`
	TraceSamplingFraction float64   `envconfig:"SKILLSGO_HUB_TRACE_SAMPLING_FRACTION"`
	StatsExporter         string    `envconfig:"SKILLSGO_HUB_STATS_EXPORTER"`
	StorageType           string    `envconfig:"SKILLSGO_HUB_STORAGE_TYPE"            validate:"required"`
	GlobalEndpoint        string    `envconfig:"SKILLSGO_HUB_GLOBAL_ENDPOINT"` // This feature is not yet implemented
	Port                  string    `envconfig:"SKILLSGO_HUB_PORT"`
	UnixSocket            string    `envconfig:"SKILLSGO_HUB_UNIX_SOCKET"`
	BasicAuthUser         string    `envconfig:"SKILLSGO_HUB_BASIC_AUTH_USER"`
	BasicAuthPass         string    `envconfig:"SKILLSGO_HUB_BASIC_AUTH_PASS"`
	HomeTemplatePath      string    `envconfig:"SKILLSGO_HUB_HOME_TEMPLATE_PATH"`
	ForceSSL              bool      `envconfig:"SKILLSGO_HUB_FORCE_SSL"`
	ValidatorHook         string    `envconfig:"SKILLSGO_HUB_PROXY_VALIDATOR"`
	PathPrefix            string    `envconfig:"SKILLSGO_HUB_PATH_PREFIX"`
	NETRCPath             string    `envconfig:"SKILLSGO_HUB_NETRC_PATH"`
	GithubTokens          TokenList `envconfig:"SKILLSGO_HUB_GITHUB_TOKENS"`
	HGRCPath              string    `envconfig:"SKILLSGO_HUB_HGRC_PATH"`
	TLSCertFile           string    `envconfig:"SKILLSGO_HUB_TLSCERT_FILE"`
	TLSKeyFile            string    `envconfig:"SKILLSGO_HUB_TLSKEY_FILE"`
	DownloadMode          mode.Mode `envconfig:"SKILLSGO_HUB_DOWNLOAD_MODE"`
	DownloadURL           string    `envconfig:"SKILLSGO_HUB_DOWNLOAD_URL"`
	NetworkMode           string    `envconfig:"SKILLSGO_HUB_NETWORK_MODE"            validate:"oneof=strict offline fallback"`
	SingleFlightType      string    `envconfig:"SKILLSGO_HUB_SINGLE_FLIGHT_TYPE"`
	RobotsFile            string    `envconfig:"SKILLSGO_HUB_ROBOTS_FILE"`
	IndexType             string    `envconfig:"SKILLSGO_HUB_INDEX_TYPE"`
	ShutdownTimeout       int       `envconfig:"SKILLSGO_HUB_SHUTDOWN_TIMEOUT"        validate:"min=0"`
	StashTimeout          int       `envconfig:"SKILLSGO_HUB_STASH_TIMEOUT"`
	SingleFlight          *SingleFlight
	Storage               *Storage
	Index                 *Index
	Database              *DatabaseConfig
	LLM                   *LLMConfig
	SkillsSH              *SkillsSHConfig
}

// EnvList is a list of key-value environment
// variables that are passed to the Go command.
type EnvList []string

// TokenList supports TOML arrays and comma, semicolon, or newline-delimited
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
		Environment:           "development",
		GithubTokens:          TokenList{},
		SkillFetchWorkers:     10,
		ProtocolWorkers:       30,
		LogLevel:              "debug",
		LogFormat:             "plain",
		CloudRuntime:          "none",
		EnablePprof:           false,
		PprofPort:             ":3001",
		StatsExporter:         "prometheus",
		TimeoutConf:           TimeoutConf{Timeout: 300},
		HomeTemplatePath:      "/var/lib/athens/home.html",
		StorageType:           "disk",
		Port:                  ":3000",
		SingleFlightType:      "memory",
		GlobalEndpoint:        "http://localhost:3001",
		TraceExporterURL:      "http://localhost:4317",
		TraceSamplingFraction: 1.0,
		DownloadMode:          "sync",
		DownloadURL:           "",
		NetworkMode:           "strict",
		RobotsFile:            "robots.txt",
		IndexType:             "none",
		ShutdownTimeout:       60,
		StashTimeout:          600,
		Storage: &Storage{
			Disk: &DiskConfig{},
		},
		SingleFlight: &SingleFlight{
			Etcd:  &Etcd{"localhost:2379,localhost:22379,localhost:32379"},
			Redis: &Redis{Endpoint: "127.0.0.1:6379", LockConfig: DefaultRedisLockConfig()},
			RedisSentinel: &RedisSentinel{
				Endpoints:        []string{"127.0.0.1:26379"},
				MasterName:       "redis-1",
				SentinelPassword: "sekret",
				RedisUsername:    "",
				RedisPassword:    "",
				DB:               0,
				LockConfig:       DefaultRedisLockConfig(),
			},
			GCP: DefaultGCPConfig(),
		},
		Index: &Index{
			MySQL: &MySQL{
				Protocol: "tcp",
				Host:     "localhost",
				Port:     3306,
				User:     "root",
				Password: "",
				Database: "athens",
				Params: map[string]string{
					"parseTime": "true",
					"timeout":   "30s",
				},
			},
			Postgres: &Postgres{
				Host:     "localhost",
				Port:     5432,
				User:     "postgres",
				Password: "",
				Database: "athens",
				Params: map[string]string{
					"connect_timeout": "30",
					"sslmode":         "disable",
				},
			},
		},
		Database: &DatabaseConfig{
			Type:            "sqlite",
			MaxOpenConns:    1,
			MaxIdleConns:    1,
			ConnMaxLifetime: 0,
		},
		LLM: &LLMConfig{
			BaseURL: "https://api.deepseek.com", Model: "deepseek-v4-flash",
			TranslationLocales: []string{"zh-Hans"}, TranslationInterval: 900,
			TranslationBatch: 100, PromptVersion: "description-v1",
		},
		SkillsSH: &SkillsSHConfig{
			Interval: 600, LeaseSeconds: 120, PageCount: 10, PerPage: 500, RequestTimeout: 60,
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
	if _, err := toml.DecodeFile(configFile, config); err != nil {
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

// envOverride uses Environment variables to override unspecified properties.
func envOverride(config *Config) error {
	const defaultPort = ":3000"
	err := envconfig.Process("", config)
	if err != nil {
		return err
	}
	config.SkillCacheDir, err = resolveHubCacheDir(config.SkillCacheDir)
	if err != nil {
		return err
	}
	if config.Database == nil {
		config.Database = &DatabaseConfig{Type: "sqlite", MaxOpenConns: 1, MaxIdleConns: 1}
	}
	if config.LLM == nil {
		config.LLM = defaultConfig().LLM
	}
	seenLocales := make(map[string]bool, len(config.LLM.TranslationLocales))
	canonicalLocales := make([]string, 0, len(config.LLM.TranslationLocales))
	for _, locale := range config.LLM.TranslationLocales {
		canonical, canonicalErr := presentation.CanonicalLocale(locale)
		if canonicalErr != nil {
			return canonicalErr
		}
		if !seenLocales[canonical] {
			seenLocales[canonical] = true
			canonicalLocales = append(canonicalLocales, canonical)
		}
	}
	config.LLM.TranslationLocales = canonicalLocales
	config.Database.DSN, err = resolveHubDatabaseDSN(config.Database.Type, config.Database.DSN)
	if err != nil {
		return err
	}
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
	return nil
}

func ensurePortFormat(s string) string {
	if _, err := strconv.Atoi(s); err == nil {
		return ":" + s
	}
	return s
}

func validateConfig(config Config) error {
	validate := validator.New()
	err := validate.StructExcept(config, "Storage", "Index", "Database")
	if err != nil {
		return err
	}
	err = validateStorage(validate, config.StorageType, config.Storage)
	if err != nil {
		return err
	}
	err = validateIndex(validate, config.IndexType, config.Index)
	if err != nil {
		return err
	}
	if err := validateDatabase(validate, config.Database); err != nil {
		return err
	}
	return validate.Struct(config.LLM)
}

func validateDatabase(validate *validator.Validate, database *DatabaseConfig) error {
	if database == nil {
		return fmt.Errorf("database configuration is required")
	}
	if err := validate.Struct(database); err != nil {
		return err
	}
	if database.Type == "postgres" && database.DSN == "" {
		return fmt.Errorf("database DSN is required")
	}
	return nil
}

func validateStorage(validate *validator.Validate, storageType string, config *Storage) error {
	switch storageType {
	case "memory":
		return nil
	case "mongo":
		return validate.Struct(config.Mongo)
	case "disk":
		return validate.Struct(config.Disk)
	case "minio":
		return validate.Struct(config.Minio)
	case "gcp":
		return validate.Struct(config.GCP)
	case "s3":
		return validate.Struct(config.S3)
	case "azureblob":
		return validate.Struct(config.AzureBlob)
	case "external":
		return validate.Struct(config.External)
	default:
		return fmt.Errorf("storage type %q is unknown", storageType)
	}
}

func validateIndex(validate *validator.Validate, indexType string, config *Index) error {
	switch indexType {
	case "", "none", "memory":
		return nil
	case "mysql":
		return validate.Struct(config.MySQL)
	case "postgres":
		return validate.Struct(config.Postgres)
	default:
		return fmt.Errorf("index type %q is unknown", indexType)
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
