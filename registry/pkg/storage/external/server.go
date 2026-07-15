package external

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
	"github.com/skillsgo/skillsgo/registry/pkg/download"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/paths"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"golang.org/x/mod/zip"
)

// NewServer takes a storage.Backend implementation of your
// choice, and returns a new http.Handler that Athens can
// reach out to for storage operations.
func NewServer(strg storage.Backend) http.Handler {
	r := mux.NewRouter()
	r.HandleFunc(download.PathList, func(w http.ResponseWriter, r *http.Request) {
		skill := mux.Vars(r)["skill"]
		list, err := strg.List(r.Context(), skill)
		if err != nil {
			http.Error(w, err.Error(), errors.Kind(err))
			return
		}
		_, _ = fmt.Fprintf(w, "%s", strings.Join(list, "\n"))
	}).Methods(http.MethodGet)
	r.HandleFunc(download.PathVersionInfo, func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r)
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
	}).Methods(http.MethodGet)
	r.HandleFunc(download.PathVersionManifest, func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		mod, err := strg.Manifest(r.Context(), params.Skill, params.Version)
		if err != nil {
			http.Error(w, err.Error(), errors.Kind(err))
			return
		}
		_, _ = w.Write(mod)
	}).Methods(http.MethodGet)
	r.HandleFunc(download.PathVersionZip, func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r)
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
	}).Methods(http.MethodGet)
	r.HandleFunc("/{skill:.+}/@v/{version}.save", func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r)
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
		manifestReader, _, err := r.FormFile("manifest.yaml")
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		defer func() { _ = manifestReader.Close() }()
		modFile, err := io.ReadAll(manifestReader)
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
		err = strg.Save(r.Context(), params.Skill, params.Version, modFile, modZ, nil, info)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
	}).Methods(http.MethodPost)

	r.HandleFunc("/{skill:.+}/@v/{version}.delete", func(w http.ResponseWriter, r *http.Request) {
		params, err := paths.GetAllParams(r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		err = strg.Delete(r.Context(), params.Skill, params.Version)
		if err != nil {
			http.Error(w, err.Error(), errors.Kind(err))
			return
		}
	}).Methods(http.MethodDelete)
	return r
}
