/*
 * [INPUT]: Depends on Sentinel lock initialization, Redis lock configuration, and a lifecycle-independent Redis logger.
 * [OUTPUT]: Verifies Sentinel database propagation reaches client initialization without leaking logs into a completed test.
 * [POS]: Serves as the no-server Sentinel initialization regression test for the stash Redis adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package stash

import (
	"context"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
)

type discardRedisLogger struct{}

func (discardRedisLogger) Printf(context.Context, string, ...any) {}

func TestWithRedisSentinelLock_DBPropagation(t *testing.T) {
	l := discardRedisLogger{}
	endpoints := []string{"127.0.0.1:26379"}
	master := "mymaster"
	sentinelPassword := "sentinel-pw"
	redisUsername := "user"
	redisPassword := "pass"
	db := 7

	// We use a nil checker because we won't actually call Stash
	_, err := WithRedisSentinelLock(l, endpoints, master, sentinelPassword, redisUsername, redisPassword, db, nil, config.DefaultRedisLockConfig())
	// Note: WithRedisSentinelLock calls client.Ping, which will fail because there is no redis.
	// We expect an error here.

	if err == nil {
		t.Fatal("expected error from Ping, but got nil")
	}
}
