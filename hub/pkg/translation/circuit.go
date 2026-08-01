/*
 * [INPUT]: Depends on classified provider failures, caller-supplied time, and a bounded payment cooldown.
 * [OUTPUT]: Provides one process-shared provider admission circuit that blocks model calls after payment failure.
 * [POS]: Serves as the cost-safety boundary shared by description and document translation workers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"sync"
	"time"
)

type ProviderCircuit struct {
	mu           sync.Mutex
	paymentDelay time.Duration
	blockedUntil time.Time
}

func NewProviderCircuit(paymentDelay time.Duration) *ProviderCircuit {
	return &ProviderCircuit{paymentDelay: paymentDelay}
}

func (c *ProviderCircuit) Delay(now time.Time) time.Duration {
	if c == nil {
		return 0
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if !now.Before(c.blockedUntil) {
		return 0
	}
	return c.blockedUntil.Sub(now)
}

func (c *ProviderCircuit) Observe(err error, now time.Time) (time.Duration, bool) {
	if c == nil || FailureKind(err) != "provider_payment_required" {
		return 0, false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	until := now.Add(c.paymentDelay)
	tripped := !now.Before(c.blockedUntil)
	if until.After(c.blockedUntil) {
		c.blockedUntil = until
	}
	return c.blockedUntil.Sub(now), tripped
}
