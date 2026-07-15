package config

// SingleFlight holds the various
// backend configurations for a distributed
// lock or single flight mechanism.
type SingleFlight struct {
	Etcd          *Etcd
	Redis         *Redis
	RedisSentinel *RedisSentinel
	GCP           *GCP
}

// Etcd holds client side configuration
// that helps Athens connect to the
// Etcd backends.
type Etcd struct {
	Endpoints string `envconfig:"SKILLSGO_REGISTRY_ETCD_ENDPOINTS"`
}

// Redis holds the client side configuration
// to connect to redis as a SingleFlight implementation.
type Redis struct {
	Endpoint   string `envconfig:"SKILLSGO_REGISTRY_REDIS_ENDPOINT"`
	Password   string `envconfig:"SKILLSGO_REGISTRY_REDIS_PASSWORD"`
	Cluster    bool   `envconfig:"SKILLSGO_REGISTRY_REDIS_CLUSTER"`
	LockConfig *RedisLockConfig
}

// RedisSentinel is the configuration for using redis with sentinel
// for SingleFlight.
type RedisSentinel struct {
	Endpoints        []string `envconfig:"SKILLSGO_REGISTRY_REDIS_SENTINEL_ENDPOINTS"`
	MasterName       string   `envconfig:"SKILLSGO_REGISTRY_REDIS_SENTINEL_MASTER_NAME"`
	SentinelPassword string   `envconfig:"SKILLSGO_REGISTRY_REDIS_SENTINEL_PASSWORD"`
	RedisUsername    string   `envconfig:"SKILLSGO_REGISTRY_REDIS_USERNAME"`
	RedisPassword    string   `envconfig:"SKILLSGO_REGISTRY_REDIS_PASSWORD"`
	DB               int      `envconfig:"SKILLSGO_REGISTRY_REDIS_SENTINEL_DB"`
	LockConfig       *RedisLockConfig
}

// RedisLockConfig is the configuration for redis locking.
type RedisLockConfig struct {
	Timeout    int `envconfig:"SKILLSGO_REGISTRY_REDIS_LOCK_TIMEOUT"`
	TTL        int `envconfig:"SKILLSGO_REGISTRY_REDIS_LOCK_TTL"`
	MaxRetries int `envconfig:"SKILLSGO_REGISTRY_REDIS_LOCK_MAX_RETRIES"`
}

// DefaultRedisLockConfig returns the default redis locking configuration.
func DefaultRedisLockConfig() *RedisLockConfig {
	return &RedisLockConfig{
		TTL:        900,
		Timeout:    15,
		MaxRetries: 10,
	}
}

// GCP is the configuration for GCP locking.
type GCP struct {
	StaleThreshold int `envconfig:"SKILLSGO_REGISTRY_GCP_STALE_THRESHOLD"`
}

// DefaultGCPConfig returns the default GCP locking configuration.
func DefaultGCPConfig() *GCP {
	return &GCP{
		StaleThreshold: 120,
	}
}
