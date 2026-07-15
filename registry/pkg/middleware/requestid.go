package middleware

import (
	"net/http"

	"github.com/google/uuid"
	"github.com/skillsgo/skillsgo/registry/pkg/requestid"
)

// WithRequestID ensures a request id is in the
// request context by either the incoming header
// or creating a new one.
func WithRequestID(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := r.Header.Get(requestid.HeaderKey)
		if requestID == "" {
			requestID = uuid.New().String()
		}
		ctx := requestid.SetInContext(r.Context(), requestID)
		r = r.WithContext(ctx)
		h.ServeHTTP(w, r)
	})
}
