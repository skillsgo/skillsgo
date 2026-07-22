/*
 * [INPUT]: Depends on the external storage HTTP protocol, escaped immutable coordinates, and multipart Info/ZIP streams.
 * [OUTPUT]: Provides an external Backend client with server-authoritative PutIfAbsent result semantics.
 * [POS]: Serves as the Hub-side adapter to a single external storage service that owns cross-process publication races.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package external

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"golang.org/x/mod/module"
)

type service struct {
	url string
	c   *http.Client
}

// NewClient returns an external storage client.
func NewClient(url string, c *http.Client) storage.Backend {
	if c == nil {
		c = &http.Client{}
	}
	url = strings.TrimSuffix(url, "/")
	return &service{url, c}
}

func (s *service) List(ctx context.Context, mod string) ([]string, error) {
	const op errors.Op = "external.List"
	body, _, err := s.getRequest(ctx, mod, "list", "")
	if err != nil {
		return nil, errors.E(op, err)
	}
	list := []string{}
	scnr := bufio.NewScanner(body)
	for scnr.Scan() {
		list = append(list, scnr.Text())
	}
	if scnr.Err() != nil {
		return nil, errors.E(op, scnr.Err())
	}
	return list, nil
}

func (s *service) Info(ctx context.Context, mod, ver string) ([]byte, error) {
	const op errors.Op = "external.Info"
	body, _, err := s.getRequest(ctx, mod, ver, "info")
	if err != nil {
		return nil, errors.E(op, err)
	}
	info, err := io.ReadAll(body)
	if err != nil {
		return nil, errors.E(op, err)
	}
	return info, nil
}

func (s *service) Zip(ctx context.Context, mod, ver string) (storage.SizeReadCloser, error) {
	const op errors.Op = "external.Zip"
	body, size, err := s.getRequest(ctx, mod, ver, "zip")
	if err != nil {
		return nil, errors.E(op, err)
	}
	return storage.NewSizer(body, size), nil
}

func (s *service) Save(ctx context.Context, mod, ver string, zip io.Reader, zipMD5, info []byte) error {
	_, err := s.PutIfAbsent(ctx, mod, ver, zip, zipMD5, info)
	return err
}

// PutIfAbsent delegates the immutable coordinate decision to the external storage server.
func (s *service) PutIfAbsent(ctx context.Context, mod, ver string, zip io.Reader, zipMD5, info []byte) (bool, error) {
	const op errors.Op = "external.Save"
	var err error
	mod, err = module.EscapePath(mod)
	if err != nil {
		return false, errors.E(op, err)
	}
	url := s.url + "/" + mod + "/@v/" + ver + ".save"
	pr, pw := io.Pipe()
	mw := multipart.NewWriter(pw)
	go func() {
		err := upload(mw, info, zip)
		_ = pw.CloseWithError(err)
	}()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, pr)
	if err != nil {
		return false, errors.E(op, err)
	}
	req.Header.Add("Content-Type", mw.FormDataContentType())
	resp, err := s.c.Do(req)
	if err != nil {
		return false, errors.E(op, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		bts, _ := io.ReadAll(resp.Body)
		return false, errors.E(op, fmt.Errorf("unexpected status code: %v - body: %s", resp.StatusCode, bts), resp.StatusCode)
	}
	return resp.StatusCode == http.StatusCreated, nil
}

func (s *service) Delete(ctx context.Context, mod, ver string) error {
	const op errors.Op = "external.Delete"
	body, _, err := s.doRequest(ctx, "DELETE", mod, ver, "delete")
	if err != nil {
		return errors.E(op, err)
	}
	defer func() { _ = body.Close() }()
	return nil
}

func upload(mw *multipart.Writer, info []byte, zip io.Reader) error {
	defer func() { _ = mw.Close() }()
	infoW, err := mw.CreateFormFile("info.json", "info.json")
	if err != nil {
		return fmt.Errorf("error creating info file: %w", err)
	}
	_, err = infoW.Write(info)
	if err != nil {
		return fmt.Errorf("error writing info file: %w", err)
	}
	zipW, err := mw.CreateFormFile("skill.zip", "skill.zip")
	if err != nil {
		return fmt.Errorf("error creating zip file: %w", err)
	}
	_, err = io.Copy(zipW, zip)
	if err != nil {
		return fmt.Errorf("error writing zip file: %w", err)
	}
	return nil
}

func (s *service) getRequest(ctx context.Context, mod, ver, ext string) (io.ReadCloser, int64, error) {
	return s.doRequest(ctx, "GET", mod, ver, ext)
}

func (s *service) doRequest(ctx context.Context, method, mod, ver, ext string) (io.ReadCloser, int64, error) {
	const op errors.Op = "external.doRequest"
	var err error
	mod, err = module.EscapePath(mod)
	if err != nil {
		return nil, 0, errors.E(op, err)
	}
	url := s.url + "/" + mod + "/@v/" + ver
	if ext != "" {
		url += "." + ext
	}
	req, err := http.NewRequestWithContext(ctx, method, url, nil)
	if err != nil {
		return nil, 0, errors.E(op, err)
	}
	resp, err := s.c.Do(req)
	if err != nil {
		return nil, 0, errors.E(op, err)
	}
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		_ = resp.Body.Close()
		return nil, 0, errors.E(op, fmt.Errorf("none 200 status code: %v - body: %s", resp.StatusCode, body), resp.StatusCode)
	}
	var size int64
	if cl := resp.Header.Get("Content-Length"); cl != "" {
		size, err = strconv.ParseInt(cl, 10, 64)
		if err != nil {
			return nil, 0, errors.E(op, fmt.Errorf("could not parse content-length(%q): %w", cl, err))
		}
	}
	return resp.Body, size, nil
}
