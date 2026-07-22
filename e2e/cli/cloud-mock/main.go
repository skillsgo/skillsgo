/*
 * [INPUT]: Depends on the public Cloud Mock handler and an isolated E2E-only observation route.
 * [OUTPUT]: Provides a standalone Cloud test process on port 3100 with observable accepted install events.
 * [POS]: Serves as the external Cloud boundary in public CLI-plus-Hub E2E journeys without reproducing private Cloud implementation.
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
	server := &http.Server{Addr: ":3100", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(server.ListenAndServe())
}
