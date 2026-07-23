//go:build e2etests
// +build e2etests

/*
 * [INPUT]: Depends on the Hub binary, Testcontainers PostgreSQL, one suite-private filesystem root, and inherited proxy settings.
 * [OUTPUT]: Provides an isolated build-tag Hub acceptance lifecycle with private Catalog, Storage, source cache, and Go build cache state.
 * [POS]: Serves as the suite bootstrap preventing protocol acceptance tests from observing prior local Hub state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2etests

import (
	"context"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"testing"

	"github.com/gobuffalo/envy"
	"github.com/stretchr/testify/suite"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

type E2eSuite struct {
	suite.Suite
	goBinaryPath string
	env          []string
	goPath       string
	hubOrigin    string
	stopAthens   context.CancelFunc
	postgres     testcontainers.Container
	databaseDSN  string
}

func (m *E2eSuite) SetupSuite() {
	var err error
	m.goPath, err = os.MkdirTemp("/tmp", "gopath")
	if err != nil {
		m.Fail("Failed to make temp dir", err)
	}

	m.goBinaryPath = envy.Get("GO_BINARY_PATH", "go")
	container, err := postgres.Run(context.Background(), "postgres:18-alpine", postgres.WithDatabase("skillsgo"), postgres.WithUsername("skillsgo"), postgres.WithPassword("skillsgo"), postgres.BasicWaitStrategies())
	m.Require().NoError(err)
	m.postgres = container
	m.databaseDSN, err = container.ConnectionString(context.Background(), "sslmode=disable")
	m.Require().NoError(err)

	athensBin, err := buildAthens(m.goBinaryPath, m.goPath, m.env)
	if err != nil {
		m.Fail("Failed to build athens ", err)
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	m.Require().NoError(err)
	port := listener.Addr().(*net.TCPAddr).Port
	m.Require().NoError(listener.Close())
	m.hubOrigin = fmt.Sprintf("http://127.0.0.1:%d", port)

	ctx := context.Background()
	ctx, m.stopAthens = context.WithCancel(ctx)
	m.Require().NoError(runAthensAndWait(ctx, athensBin, m.getEnv(port), m.hubOrigin))
}

func (m *E2eSuite) TearDownSuite() {
	m.stopAthens()
	if m.postgres != nil {
		m.Require().NoError(m.postgres.Terminate(context.Background()))
	}
	chmodR(m.goPath, 0o777)
	os.RemoveAll(m.goPath)
}

func TestE2E(t *testing.T) {
	suite.Run(t, &E2eSuite{})
}

func (m *E2eSuite) getEnv(port int) []string {
	res := []string{
		fmt.Sprintf("GOPATH=%s", m.goPath),
		"GO111MODULE=on",
		fmt.Sprintf("PATH=%s", os.Getenv("PATH")),
		fmt.Sprintf("GOCACHE=%s", filepath.Join(m.goPath, "cache")),
		fmt.Sprintf("SKILLSGO_HUB_CACHE_DIR=%s", filepath.Join(m.goPath, "source-cache")),
		"SKILLSGO_HUB_STORAGE_TYPE=disk",
		fmt.Sprintf("SKILLSGO_HUB_DISK_STORAGE_ROOT=%s", filepath.Join(m.goPath, "storage")),
		"SKILLSGO_HUB_DATABASE_TYPE=postgres",
		fmt.Sprintf("SKILLSGO_HUB_DATABASE_DSN=%s", m.databaseDSN),
		fmt.Sprintf("SKILLSGO_HUB_PORT=:%d", port),
	}
	for _, name := range []string{"HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy", "NO_PROXY", "no_proxy"} {
		if value, ok := os.LookupEnv(name); ok {
			res = append(res, fmt.Sprintf("%s=%s", name, value))
		}
	}
	return res
}
