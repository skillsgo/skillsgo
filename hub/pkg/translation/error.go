/*
 * [INPUT]: Depends on errors returned by deterministic translation validation and external infrastructure adapters.
 * [OUTPUT]: Provides named permanent and retryable failure classification without coupling translation policy to River.
 * [POS]: Serves as the retry-semantics boundary between translation workers and task transport.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"errors"
	"net/http"

	"github.com/openai/openai-go/v3"
)

type permanentError struct {
	kind string
	error
}

func (e permanentError) Unwrap() error { return e.error }

type retryableError struct {
	kind string
	error
}

func (e retryableError) Unwrap() error { return e.error }

func Permanent(err error) error {
	return permanent("validation", err)
}

func permanent(kind string, err error) error {
	if err == nil {
		return nil
	}
	return permanentError{kind: kind, error: err}
}

func FailureKind(err error) string {
	var target permanentError
	if errors.As(err, &target) {
		return target.kind
	}
	var retryable retryableError
	if errors.As(err, &retryable) {
		return retryable.kind
	}
	return "retry_exhausted"
}

func IsPermanent(err error) bool {
	var target permanentError
	return errors.As(err, &target)
}

func classifyProviderError(err error) error {
	var apiErr *openai.Error
	if !errors.As(err, &apiErr) {
		return err
	}
	if apiErr.StatusCode == http.StatusPaymentRequired {
		return retryableError{kind: "provider_payment_required", error: err}
	}
	if apiErr.StatusCode >= http.StatusBadRequest && apiErr.StatusCode < http.StatusInternalServerError &&
		apiErr.StatusCode != http.StatusRequestTimeout &&
		apiErr.StatusCode != http.StatusConflict &&
		apiErr.StatusCode != http.StatusTooManyRequests {
		return permanent("provider_rejected", err)
	}
	return err
}
