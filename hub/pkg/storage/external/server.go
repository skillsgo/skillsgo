/*
 * [INPUT]: Depends on the storage Backend contract, decoded artifact paths, multipart uploads, and standard HTTP transport.
 * [OUTPUT]: Provides the standalone external-storage HTTP handler for list, read, save, and delete operations.
 * [POS]: Serves as the explicit standard-library transport boundary outside the Fiber Hub application.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package external

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"golang.org/x/mod/zip"
)

// NewServer takes a storage.Backend implementation of your
// choice, and returns a new http.Handler that Athens can
// reach out to for storage operations.
func NewServer(strg storage.Backend) http.Handler {
	listHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		skill, err := paths.GetSkill(r.URL.Path)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		list, err := strg.List(r.Context(), skill)
		if err != nil {
			http.Error(w, err.Error(), errors.Kind(err))
			return
		}
		_, _ = fmt.Fprintf(w, "%s", strings.Join(list, "\n"))
	})
	infoHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r.URL.Path)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		info, err := strg.Info(r.Context(), params.Skill, params.Version)
		if err != nil {
			http.Error(w, err.Error(), errors.Kind(err))
			return
		}
		_, _ = w.Write(info)
	})
	zipHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r.URL.Path)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		zip, err := strg.Zip(r.Context(), params.Skill, params.Version)
		if err != nil {
			http.Error(w, err.Error(), errors.Kind(err))
			return
		}
		defer func() { _ = zip.Close() }()
		w.Header().Set("Content-Length", strconv.FormatInt(zip.Size(), 10))
		_, _ = io.Copy(w, zip)
	})
	saveHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r.URL.Path)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
		err = r.ParseMultipartForm(zip.MaxZipFile + zip.MaxGoMod)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		infoFile, _, err := r.FormFile("info.json")
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		defer func() { _ = infoFile.Close() }()
		info, err := io.ReadAll(infoFile)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		modZ, _, err := r.FormFile("skill.zip")
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		defer func() { _ = modZ.Close() }()
		err = strg.Save(r.Context(), params.Skill, params.Version, modZ, nil, info)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
	})

	deleteHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r.URL.Path)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		err = strg.Delete(r.Context(), params.Skill, params.Version)
		if err != nil {
			http.Error(w, err.Error(), errors.Kind(err))
			return
		}
	})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestPath := r.URL.Path
		switch {
		case r.Method == http.MethodGet && strings.HasSuffix(requestPath, "/@v/list"):
			listHandler.ServeHTTP(w, r)
		case r.Method == http.MethodGet && strings.HasSuffix(requestPath, ".info"):
			infoHandler.ServeHTTP(w, r)
		case r.Method == http.MethodGet && strings.HasSuffix(requestPath, ".zip"):
			zipHandler.ServeHTTP(w, r)
		case r.Method == http.MethodPost && strings.HasSuffix(requestPath, ".save"):
			saveHandler.ServeHTTP(w, r)
		case r.Method == http.MethodDelete && strings.HasSuffix(requestPath, ".delete"):
			deleteHandler.ServeHTTP(w, r)
		default:
			http.NotFound(w, r)
		}
	})
}
