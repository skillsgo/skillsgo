/*
 * [INPUT]: Depends on the authenticated Vercel skills.sh bridge HTTP contract and bounded page batch requests.
 * [OUTPUT]: Provides typed all-time leaderboard page batches with upstream counter observations and pagination metadata.
 * [POS]: Serves as the network adapter used only by the skills.sh synchronization worker.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillssh

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type Skill struct {
	ID       string `json:"id"`
	Source   string `json:"source"`
	Slug     string `json:"slug"`
	Installs int64  `json:"installs"`
}

type Page struct {
	Page    int
	Data    []Skill
	Total   int
	HasMore bool
}

type bridgeResponse struct {
	FetchedAt time.Time `json:"fetchedAt"`
	Pages     []struct {
		Page   int `json:"page"`
		Status int `json:"status"`
		Body   struct {
			Data       []Skill `json:"data"`
			Pagination struct {
				Page    int  `json:"page"`
				Total   int  `json:"total"`
				HasMore bool `json:"hasMore"`
			} `json:"pagination"`
		} `json:"body"`
	} `json:"pages"`
}

type Client struct {
	url   string
	token string
	http  *http.Client
}

func NewClient(url, token string, timeout time.Duration) *Client {
	return &Client{url: strings.TrimRight(url, "/"), token: token, http: &http.Client{Timeout: timeout}}
}

func (c *Client) Fetch(ctx context.Context, startPage, pageCount, perPage int) ([]Page, time.Time, error) {
	payload, _ := json.Marshal(map[string]any{"view": "all-time", "startPage": startPage, "pageCount": pageCount, "perPage": perPage})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.url, bytes.NewReader(payload))
	if err != nil {
		return nil, time.Time{}, err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")
	response, err := c.http.Do(req)
	if err != nil {
		return nil, time.Time{}, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1024))
		return nil, time.Time{}, fmt.Errorf("bridge returned %d: %s", response.StatusCode, strings.TrimSpace(string(body)))
	}
	var decoded bridgeResponse
	if err := json.NewDecoder(io.LimitReader(response.Body, 5<<20)).Decode(&decoded); err != nil {
		return nil, time.Time{}, err
	}
	pages := make([]Page, 0, len(decoded.Pages))
	for _, page := range decoded.Pages {
		if page.Status != http.StatusOK {
			return nil, time.Time{}, fmt.Errorf("skills.sh page %d returned %d", page.Page, page.Status)
		}
		pages = append(pages, Page{Page: page.Page, Data: page.Body.Data, Total: page.Body.Pagination.Total, HasMore: page.Body.Pagination.HasMore})
	}
	if decoded.FetchedAt.IsZero() {
		decoded.FetchedAt = time.Now().UTC()
	}
	return pages, decoded.FetchedAt, nil
}
