//go:build e2etests
// +build e2etests

package e2etests

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/gobuffalo/envy"
	"github.com/stretchr/testify/suite"
)

type E2eSuite struct {
	suite.Suite
	goBinaryPath string
	env          []string
	goPath       string
	stopAthens   context.CancelFunc
}

func (m *E2eSuite) SetupSuite() {
	var err error
	m.goPath, err = os.MkdirTemp("/tmp", "gopath")
	if err != nil {
		m.Fail("Failed to make temp dir", err)
	}

	m.goBinaryPath = envy.Get("GO_BINARY_PATH", "go")

	athensBin, err := buildAthens(m.goBinaryPath, m.goPath, m.env)
	if err != nil {
		m.Fail("Failed to build athens ", err)
	}
	stopAthens() // in case a dangling instance was around.
	// ignoring error as if no athens is running it fails.

	ctx := context.Background()
	ctx, m.stopAthens = context.WithCancel(ctx)
	m.Require().NoError(runAthensAndWait(ctx, athensBin, m.getEnv()))
}

func (m *E2eSuite) TearDownSuite() {
	m.stopAthens()
	chmodR(m.goPath, 0o777)
	os.RemoveAll(m.goPath)
}

func TestE2E(t *testing.T) {
	suite.Run(t, &E2eSuite{})
}

func (m *E2eSuite) getEnv() []string {
	res := []string{
		fmt.Sprintf("GOPATH=%s", m.goPath),
		"GO111MODULE=on",
		fmt.Sprintf("PATH=%s", os.Getenv("PATH")),
		fmt.Sprintf("GOCACHE=%s", filepath.Join(m.goPath, "cache")),
	}
	for _, name := range []string{"HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy", "NO_PROXY", "no_proxy"} {
		if value, ok := os.LookupEnv(name); ok {
			res = append(res, fmt.Sprintf("%s=%s", name, value))
		}
	}
	return res
}
