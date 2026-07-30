/*
 * [INPUT]: Depends on the public Hub community mock handler and an isolated E2E-only observation route.
 * [OUTPUT]: Provides a standalone community-contract test process on port 3100 with observable and scenario-resettable accepted install events.
 * [POS]: Serves as the external event-observation boundary in public CLI-plus-Hub E2E journeys without reproducing consumer persistence.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/skillsgo/skillsgo/protocol/cloudtest"
)

func main() {
	mock := cloudtest.NewMock()
	mux := http.NewServeMux()
	mux.Handle("/api/", mock.Handler())
	mux.HandleFunc("GET /__e2e/events", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(mock.Events())
	})
	mux.HandleFunc("POST /__e2e/reset", func(w http.ResponseWriter, _ *http.Request) {
		mock.ResetEvents()
		w.WriteHeader(http.StatusNoContent)
	})
	server := &http.Server{Addr: ":3100", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(server.ListenAndServe())
}
