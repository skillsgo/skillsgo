/*
 * [INPUT]: Uses final Catalog card rows of varying cardinality.
 * [OUTPUT]: Specifies allocation-preserving, side-effect-free card projection whose work is linear in rows and independent of external services.
 * [POS]: Serves as the structural complexity and micro-benchmark contract for the online discovery projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"fmt"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

func TestSkillCardProjectionIsPureForEveryResultCardinality(t *testing.T) {
	projection := skillCardProjection{}
	for _, count := range []int{0, 1, 20, 100} {
		t.Run(fmt.Sprintf("rows_%d", count), func(t *testing.T) {
			rows := searchCardRows(count)
			cards := projection.Search(rows)
			require.Len(t, cards, count)
			for index := range cards {
				require.Equal(t, rows[index].PackagePath, cards[index].PackagePath)
				require.Equal(t, rows[index].Description, cards[index].Description)
			}
		})
	}
}

func BenchmarkSkillCardProjection100(b *testing.B) {
	projection := skillCardProjection{}
	rows := searchCardRows(100)
	b.ReportAllocs()
	for b.Loop() {
		_ = projection.Search(rows)
	}
}

func searchCardRows(count int) []catalog.SearchSkill {
	rows := make([]catalog.SearchSkill, 0, count)
	for index := range count {
		rows = append(rows, catalog.SearchSkill{Skill: catalog.Skill{
			PackagePath: "github.com/acme/skills", Name: fmt.Sprintf("skill-%03d", index),
			Path: fmt.Sprintf("skills/skill-%03d", index), Description: "final localized description",
			SourceHost: "github.com", SourceRepository: "acme/skills", LatestVersion: "v1.0.0",
		}})
	}
	return rows
}
