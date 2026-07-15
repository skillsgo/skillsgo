package middleware

import (
	"net/http"
	"net/url"
	"strings"

	"github.com/gorilla/mux"
	"github.com/skillsgo/skillsgo/registry/pkg/paths"
	"github.com/skillsgo/skillsgo/registry/pkg/skill"
)

// NewFilterMiddleware builds a middleware function that implements the
// filters configured in the filter file.
func NewFilterMiddleware(mf *skill.Filter, upstreamEndpoint string) mux.MiddlewareFunc {
	return func(h http.Handler) http.Handler {
		f := func(w http.ResponseWriter, r *http.Request) {
			mod, err := paths.GetSkill(r)
			if err != nil {
				// if there is no module the path we are hitting is not one related to modules, like /
				h.ServeHTTP(w, r)
				return
			}
			ver, err := paths.GetVersion(r)
			if err != nil {
				ver = ""
			}
			rule := mf.Rule(mod, ver)
			switch rule {
			case skill.Exclude:
				// Exclude: ignore request for this module
				w.WriteHeader(http.StatusForbidden)
				return
			case skill.Include:
				// Include: please handle this module in a usual way
				h.ServeHTTP(w, r)
				return
			case skill.Direct:
				// Direct: do not store modules locally, use upstream proxy
				newURL := redirectToUpstreamURL(upstreamEndpoint, r.URL)
				http.Redirect(w, r, newURL, http.StatusSeeOther)
				return
			}
			h.ServeHTTP(w, r)
		}
		return http.HandlerFunc(f)
	}
}

func redirectToUpstreamURL(upstreamEndpoint string, u *url.URL) string {
	return strings.TrimSuffix(upstreamEndpoint, "/") + u.Path
}
