/*
 * [INPUT]: Uses an HTTP test Hub and the public Execute seam with multiple installed Library-entry versions.
 * [OUTPUT]: Specifies one Repository-fresh batch request and ordered independent head/release/unsupported results.
 * [POS]: Serves as the acceptance contract for App-triggered update availability checks.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCatalogUpdateCheckUsesOneProductRequest(t *testing.T) {
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		requests++
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/updates/check" {
			t.Fatalf("unexpected request %s %s", request.Method, request.URL.Path)
		}
		var body struct {
			SchemaVersion int                 `json:"schemaVersion"`
			Skills        []map[string]string `json:"skills"`
		}
		if json.NewDecoder(request.Body).Decode(&body) != nil || body.SchemaVersion != 1 || len(body.Skills) != 3 {
			t.Fatalf("unexpected request body %+v", body)
		}
		_, _ = w.Write([]byte(`{"schemaVersion":1,"items":[{"repositoryId":"github.com/acme/skills","name":"current","headVersion":"v1.0.0","releaseVersion":"v1.0.0","status":"available"},{"repositoryId":"github.com/acme/skills","name":"review","headVersion":"v3.0.0","releaseVersion":"v2.0.0","status":"available"},{"repositoryId":"github.com/acme/skills","name":"local","status":"unsupported"}]}`))
	}))
	defer server.Close()

	var stdout bytes.Buffer
	err := Execute([]string{
		"updates", "check", "--hub", server.URL,
		"--installed", `{"key":"current","repositoryId":"github.com/acme/skills","name":"current","versions":["v1.0.0"]}`,
		"--installed", `{"key":"review","repositoryId":"github.com/acme/skills","name":"review","versions":["v1.0.0","v2.0.0"]}`,
		"--installed", `{"key":"local","repositoryId":"github.com/acme/skills","name":"local","versions":["captured-1"]}`,
	}, &stdout, &bytes.Buffer{})
	if err != nil {
		t.Fatal(err)
	}
	var report catalogUpdateReport
	if json.Unmarshal(stdout.Bytes(), &report) != nil || report.SchemaVersion != 1 || report.Phase != "update-check" || len(report.Items) != 3 {
		t.Fatalf("unexpected report %s", stdout.String())
	}
	if requests != 1 || report.Items[0].Status != "current" || report.Items[0].HeadStatus != "current" || report.Items[0].ReleaseStatus != "current" ||
		report.Items[1].Status != "update_available" || report.Items[1].HeadStatus != "update_available" || report.Items[1].ReleaseStatus != "update_available" || report.Items[2].Status != "unsupported" {
		t.Fatalf("unexpected requests=%d report=%+v", requests, report)
	}
}

func TestCatalogUpdateCheckBatchesEightyInstalledSkills(t *testing.T) {
	type responseItem struct {
		RepositoryID   string `json:"repositoryId"`
		Name           string `json:"name"`
		HeadVersion    string `json:"headVersion"`
		ReleaseVersion string `json:"releaseVersion"`
		Status         string `json:"status"`
	}
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		requests++
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/updates/check" {
			t.Fatalf("unexpected request %s %s", request.Method, request.URL.Path)
		}
		var body struct {
			SchemaVersion int                 `json:"schemaVersion"`
			Skills        []map[string]string `json:"skills"`
		}
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil || body.SchemaVersion != 1 || len(body.Skills) != 80 {
			t.Fatalf("unexpected request body %+v: %v", body, err)
		}
		items := make([]responseItem, 0, len(body.Skills))
		for _, coordinate := range body.Skills {
			items = append(items, responseItem{RepositoryID: coordinate["repositoryId"], Name: coordinate["name"], HeadVersion: "v2.0.0", ReleaseVersion: "v2.0.0", Status: "available"})
		}
		_ = json.NewEncoder(w).Encode(struct {
			SchemaVersion int         `json:"schemaVersion"`
			Items         interface{} `json:"items"`
		}{SchemaVersion: 1, Items: items})
	}))
	defer server.Close()

	arguments := []string{"updates", "check", "--hub", server.URL}
	for index := range 80 {
		arguments = append(arguments, "--installed", fmt.Sprintf(`{"key":"skill-%d","repositoryId":"github.com/acme/skills","name":"skill-%d","versions":["v1.0.0"]}`, index, index))
	}
	var stdout bytes.Buffer
	if err := Execute(arguments, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	var report catalogUpdateReport
	if err := json.Unmarshal(stdout.Bytes(), &report); err != nil || len(report.Items) != 80 {
		t.Fatalf("unexpected report %s: %v", stdout.String(), err)
	}
	if requests != 1 {
		t.Fatalf("expected one Catalog request for 80 installed Skills, got %d", requests)
	}
}
