package download

import (
	"net/http"

	"github.com/skillsgo/skillsgo/registry/pkg/download/mode"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/log"
)

// PathVersionManifest URL.
const PathVersionManifest = "/{skill:.+}/@v/{version}.manifest"

// ManifestHandler implements GET baseURL/module/@v/version.manifest.
func ManifestHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) http.Handler {
	const op errors.Op = "download.VersionManifestHandler"
	f := func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		mod, ver, err := getSkillParams(r, op)
		if err != nil {
			err = errors.E(op, errors.S(mod), errors.V(ver), err)
			lggr.SystemErr(err)
			w.WriteHeader(errors.Kind(err))
			return
		}
		manifest, err := dp.Manifest(r.Context(), mod, ver)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			err = errors.E(op, err, severityLevel)
			lggr.SystemErr(err)
			if errors.Kind(err) == errors.KindRedirect {
				url, err := getRedirectURL(df.URL(mod), r.URL.Path)
				if err != nil {
					err = errors.E(op, errors.S(mod), errors.V(ver), err)
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

		_, _ = w.Write(manifest)
	}
	return http.HandlerFunc(f)
}
