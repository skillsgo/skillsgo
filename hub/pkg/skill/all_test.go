package skill

import (
	"testing"

	"github.com/spf13/afero"
	"github.com/stretchr/testify/suite"
)

const (
	// these values need to point to a real repository that has a tag
	// github.com/NYTimes/gizmo is a example of a path that needs to be encoded so we can cover that case as well
	repoURI = "github.com/op7418/guizang-ppt-skill"
	version = "v1.1.0"
)

type SkillSuite struct {
	suite.Suite
	fs afero.Fs
}

func (m *SkillSuite) SetupTest() {
	m.fs = afero.NewMemMapFs()
}

func TestModules(t *testing.T) {
	suite.Run(t, &SkillSuite{})
}
