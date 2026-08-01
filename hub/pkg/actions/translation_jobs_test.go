/*
 * [INPUT]: Uses translation provider admission policy and River snooze control flow.
 * [OUTPUT]: Specifies shared payment-failure circuit breaking at the translation job boundary.
 * [POS]: Serves as cost-safety regression coverage for description and document translation workers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/riverqueue/river"
	"github.com/skillsgo/skillsgo/hub/pkg/translation"
	"github.com/stretchr/testify/require"
)

func TestTranslationPaymentFailureTripsSharedCircuit(t *testing.T) {
	now := time.Date(2026, time.August, 2, 1, 0, 0, 0, time.UTC)
	circuit := translation.NewProviderCircuit(6 * time.Hour)
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		http.Error(response, `{"message":"Insufficient Balance"}`, http.StatusPaymentRequired)
	}))
	defer server.Close()
	_, paymentFailure := translation.NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), "Review", "en", "zh-Hans-CN")
	require.Error(t, paymentFailure)

	err, tripped := translationJobResult(circuit, now, paymentFailure)
	require.True(t, tripped)
	var snooze *river.JobSnoozeError
	require.ErrorAs(t, err, &snooze)
	require.Equal(t, 6*time.Hour, snooze.Duration)

	delay := translationJobAdmissionDelay(circuit, now.Add(time.Minute))
	require.Equal(t, 5*time.Hour+59*time.Minute, delay)
}
