/*
 * [INPUT]: Depends on OpenAI-compatible HTTP error status semantics and translation permanent/retryable error markers.
 * [OUTPUT]: Specifies retryable payment/timeout/rate/server failures and terminal invalid-request/authentication failures.
 * [POS]: Serves as table-driven retry-classification coverage for translation task transport.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"errors"
	"net/http"
	"testing"

	"github.com/openai/openai-go/v3"
	"github.com/stretchr/testify/require"
)

func TestProviderErrorClassification(t *testing.T) {
	tests := []struct {
		name      string
		status    int
		permanent bool
	}{
		{"bad request", http.StatusBadRequest, true},
		{"unauthorized", http.StatusUnauthorized, true},
		{"payment required", http.StatusPaymentRequired, false},
		{"not found", http.StatusNotFound, true},
		{"request timeout", http.StatusRequestTimeout, false},
		{"conflict", http.StatusConflict, false},
		{"rate limited", http.StatusTooManyRequests, false},
		{"server failure", http.StatusBadGateway, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := classifyProviderError(&openai.Error{StatusCode: tt.status})
			require.Equal(t, tt.permanent, IsPermanent(err))
			if tt.status == http.StatusPaymentRequired {
				require.Equal(t, "provider_payment_required", FailureKind(err))
			}
			if tt.permanent {
				require.Equal(t, "provider_rejected", FailureKind(err))
			}
		})
	}
	plain := errors.New("network unavailable")
	require.ErrorIs(t, classifyProviderError(plain), plain)
}
