/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the middleware package behavior covered by middleware_test.go.
 * [POS]: Serves as test coverage for the middleware package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	ht "github.com/gobuffalo/httptest"
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
)

func testConfigFile(t *testing.T) (testConfigFile string) {
	testConfigFile = filepath.Join("..", "..", "config.dev.toml")
	if err := os.Chmod(testConfigFile, 0o700); err != nil {
		t.Fatalf("%s\n", err)
	}
	return testConfigFile
}

func middlewareFilterApp(filterFile, hubEndpoint string) (*fiber.App, error) {
	mf, err := newTestFilter(filterFile)
	if err != nil {
		return nil, err
	}
	app := fiber.New()
	app.Use(NewFilterMiddleware(mf, hubEndpoint))
	app.All("/*", func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusOK) })
	return app, nil
}

func newTestFilter(filterFile string) (*skill.Filter, error) {
	f, err := skill.NewFilter(filterFile)
	if err != nil {
		return nil, err
	}
	f.AddRule("github.com/skillsgo/skillsgo/hub/", nil, skill.Direct)
	f.AddRule("github.com/athens-artifacts/no-tags", nil, skill.Exclude)
	f.AddRule("github.com/athens-artifacts", nil, skill.Include)
	return f, nil
}

func Test_FilterMiddleware(t *testing.T) {
	r := require.New(t)

	filter, err := os.CreateTemp(os.TempDir(), "filter-")
	if err != nil {
		t.FailNow()
	}
	defer os.Remove(filter.Name())

	conf, err := config.GetConf(testConfigFile(t))
	if err != nil {
		t.Fatalf("Unable to parse config file: %s", err.Error())
	}

	// Test with a filter file not existing
	app, err := middlewareFilterApp("nofsfile", conf.GlobalEndpoint)
	r.Nil(app, "app should be nil when a file not exisiting")
	r.Error(err, "Expected error when a file not existing on the filesystem is given")

	app, err = middlewareFilterApp(filter.Name(), conf.GlobalEndpoint)
	r.NoError(err, "app should be successfully created in the test")
	request := func(path string) *http.Response {
		resp, testErr := app.Test(mustRequest(t, path))
		r.NoError(testErr)
		return resp
	}
	res := request("/github.com/skillsgo/skillsgo/hub/@v/list")
	r.Equal(http.StatusSeeOther, res.StatusCode)
	r.Equal(conf.GlobalEndpoint+"/github.com/skillsgo/skillsgo/hub/@v/list", res.Header.Get("Location"))

	// Excluded, expects a 403
	res = request("/github.com/athens-artifacts/no-tags/@v/list")
	r.Equal(http.StatusForbidden, res.StatusCode)

	// Private, the proxy is working and returns a 200
	res = request("/github.com/athens-artifacts/happy-path/@v/list")
	r.Equal(http.StatusOK, res.StatusCode)
}

func mustRequest(t testing.TB, path string) *http.Request {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, path, nil)
	if err != nil {
		t.Fatal(err)
	}
	return req
}

func hookFilterApp(hook string) *fiber.App {
	app := fiber.New()
	app.Use(NewValidationMiddleware(http.DefaultClient, hook))
	app.All("/*", func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusOK) })
	return app
}

type hookMock struct {
	invoked bool
	params  validationParams
	resCode int
}

func (m *hookMock) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	m.invoked = true
	w.WriteHeader(m.resCode)
	decoder := json.NewDecoder(r.Body)
	decoder.Decode(&m.params)
}

type HookTestsSuite struct {
	suite.Suite
	mock   hookMock
	server *ht.Server
	w      *fiber.App
}

func (suite *HookTestsSuite) SetupSuite() {
	suite.server = ht.NewServer(&suite.mock)
	suite.w = hookFilterApp(suite.server.URL)
}

func (suite *HookTestsSuite) SetupTest() {
	suite.mock.invoked = false
	suite.mock.resCode = 0
}

func (suite *HookTestsSuite) TearDownSuite() {
	suite.server.Close()
}

func TestHookTestSuite(t *testing.T) {
	suite.Run(t, new(HookTestsSuite))
}

func (suite *HookTestsSuite) TestHookOnList() {
	r := suite.Require()
	// list path, hook should not be hit
	_, _ = suite.w.Test(mustRequest(suite.T(), "/github.com/skillsgo/skillsgo/hub/@v/list"))
	r.False(suite.mock.invoked)
}

func (suite *HookTestsSuite) TestHookPass() {
	r := suite.Require()
	// hit and pass
	suite.mock.resCode = http.StatusOK
	res, _ := suite.w.Test(mustRequest(suite.T(), "/github.com/athens-artifacts/happy-path/@v/v1.0.0.info"))
	r.True(suite.mock.invoked)
	r.Equal(http.StatusOK, res.StatusCode)
	r.Equal("github.com/athens-artifacts/happy-path", suite.mock.params.Skill)
	r.Equal("v1.0.0", suite.mock.params.Version)
}

func (suite *HookTestsSuite) TestHookBlocks() {
	r := suite.Require()

	// hit but hook blocks
	suite.mock.resCode = http.StatusForbidden
	res, _ := suite.w.Test(mustRequest(suite.T(), "/github.com/athens-artifacts/happy-path/@v/v1.0.0.info"))
	r.True(suite.mock.invoked)
	r.Equal(http.StatusForbidden, res.StatusCode)
}

func (suite *HookTestsSuite) TestHookUnexpectedError() {
	r := suite.Require()

	// hit but unexpected error
	suite.mock.resCode = http.StatusGone
	res, _ := suite.w.Test(mustRequest(suite.T(), "/github.com/athens-artifacts/happy-path/@v/v1.0.0.info"))
	r.True(suite.mock.invoked)
	r.Equal(http.StatusInternalServerError, res.StatusCode)
}
