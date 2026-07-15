package download

import (
	"encoding/json"
	"net/http"

	"github.com/skillsgo/skillsgo/registry/pkg/download/mode"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/log"
	"github.com/skillsgo/skillsgo/registry/pkg/paths"
)

// PathLatest URL.
const PathLatest = "/{skill:.+}/@latest"

// LatestHandler implements GET baseURL/module/@latest.
func LatestHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) http.Handler {
	const op errors.Op = "download.LatestHandler"
	f := func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		mod, err := paths.GetSkill(r)
		if err != nil {
			lggr.SystemErr(errors.E(op, err))
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		info, err := dp.Latest(r.Context(), mod)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound)
			err = errors.E(op, err, severityLevel)
			lggr.SystemErr(err)
			w.WriteHeader(errors.Kind(err))
			return
		}

		if err = json.NewEncoder(w).Encode(info); err != nil {
			lggr.SystemErr(errors.E(op, err))
		}
	}
	return http.HandlerFunc(f)
}
