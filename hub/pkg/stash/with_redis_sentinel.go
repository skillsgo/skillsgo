/*
 * [INPUT]: Depends on go-redis Sentinel failover clients, Hub lock configuration, storage checks, and the shared Redis lock wrapper.
 * [OUTPUT]: Provides Sentinel-backed distributed singleflight initialization with failed-client cleanup.
 * [POS]: Serves as the Redis Sentinel locking adapter for Hub artifact stashing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package stash

import (
	"context"

	"github.com/redis/go-redis/v9"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

// WithRedisSentinelLock returns a distributed singleflight
// with a redis cluster that utilizes sentinel for quorum and failover.
func WithRedisSentinelLock(l RedisLogger, endpoints []string, master, sentinelPassword, redisUsername, redisPassword string, db int, checker storage.Checker, lockConfig *config.RedisLockConfig) (Wrapper, error) {
	const op errors.Op = "stash.WithRedisSentinelLock"
	// The redis client constructor does not return an error when no endpoints
	// are provided, so we check for ourselves.
	if len(endpoints) == 0 {
		return nil, errors.E(op, "no endpoints specified")
	}
	client := redis.NewFailoverClient(&redis.FailoverOptions{
		MasterName:       master,
		SentinelAddrs:    endpoints,
		SentinelPassword: sentinelPassword,
		Username:         redisUsername,
		Password:         redisPassword,
		DB:               db,
	})
	_, err := client.Ping(context.Background()).Result()
	if err != nil {
		_ = client.Close()
		return nil, errors.E(op, err)
	}

	lockOptions, err := lockOptionsFromConfig(lockConfig)
	if err != nil {
		_ = client.Close()
		return nil, errors.E(op, err)
	}
	redis.SetLogger(l)

	return func(s Stasher) Stasher {
		return &redisLock{client, s, checker, lockOptions}
	}, nil
}
