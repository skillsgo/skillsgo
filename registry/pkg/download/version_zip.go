package download

import (
	"io"
	"net/http"
	"strconv"

	"github.com/skillsgo/skillsgo/registry/pkg/download/mode"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/log"
)

// PathVersionZip URL.
const PathVersionZip = "/{skill:.+}/@v/{version}.zip"

// ZipHandler implements GET baseURL/module/@v/version.zip.
func ZipHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) http.Handler {
	const op errors.Op = "download.ZipHandler"
	f := func(w http.ResponseWriter, r *http.Request) {
		mod, ver, err := getSkillParams(r, op)
		if err != nil {
			lggr.SystemErr(err)
			w.WriteHeader(errors.Kind(err))
			return
		}
		zip, err := dp.Zip(r.Context(), mod, ver)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			err = errors.E(op, err, severityLevel)
			lggr.SystemErr(err)
			if errors.Kind(err) == errors.KindRedirect {
				url, err := getRedirectURL(df.URL(mod), r.URL.Path)
				if err != nil {
					lggr.SystemErr(err)
					w.WriteHeader(errors.Kind(err))
					return
				}
				http.Redirect(w, r, url, errors.KindRedirect)
				return
			}
			w.WriteHeader(errors.Kind(err))
			return
		}
		defer func() { _ = zip.Close() }()

		w.Header().Set("Content-Type", "application/zip")
		size := zip.Size()
		if size > 0 {
			w.Header().Set("Content-Length", strconv.FormatInt(size, 10))
		}
		if r.Method == http.MethodHead {
			return
		}
		_, err = io.Copy(w, zip)
		if err != nil {
			lggr.SystemErr(errors.E(op, errors.S(mod), errors.V(ver), err))
		}
	}
	return http.HandlerFunc(f)
}
