/*
 * [INPUT]: Depends on canonical Module paths, shared Version Query parsing, demand publication, Versions/Skills Catalog rows, immutable SKILL.md sidecar storage, and Fiber routing.
 * [OUTPUT]: Provides GET /api/v1/{modulePath}/versions/{version}/skills?path={path} with canonical Module Version Skill content.
 * [POS]: Serves as the version-scoped Skill member resource beside Module metadata and immutable ZIP distribution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"fmt"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

func registerModuleSkillRoute(router fiber.Router, metadata *catalog.Catalog, materializer repositoryMaterializer, contents storage.SkillContentStore) {
	router.Get("/api/v1/+/versions/:version/skills", moduleSkillHandler(metadata, materializer, contents))
}

func moduleSkillHandler(metadata *catalog.Catalog, materializer repositoryMaterializer, contents storage.SkillContentStore) fiber.Handler {
	return func(c fiber.Ctx) error {
		modulePath, err := paths.GetSkill(c.Path())
		if err != nil || validateModuleResource(modulePath) != nil {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_module_path", "modulePath must be canonical")
		}
		query, err := protocolversion.ParseQuery(c.Params("version"))
		if err != nil {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_module_version_query", err.Error())
		}
		skillPath := strings.TrimSpace(c.Query("path"))
		if skillPath != "." && !protocolartifact.ValidRelativePath(skillPath) {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_skill_path", "path must be an exact relative Skill path")
		}
		version := query.Value
		if query.Movable() {
			version, err = materializer.Materialize(c.Context(), modulePath, query.Value)
			if err != nil {
				return writeModuleSkillError(c, err)
			}
		}
		identity, found, err := metadata.ModuleVersionByCoordinate(c.Context(), modulePath, version)
		if err != nil {
			return writeModuleSkillError(c, err)
		}
		if !found {
			version, err = materializer.Materialize(c.Context(), modulePath, query.Value)
			if err != nil {
				return writeModuleSkillError(c, err)
			}
			identity, found, err = metadata.ModuleVersionByCoordinate(c.Context(), modulePath, version)
			if err != nil {
				return writeModuleSkillError(c, err)
			}
			if !found {
				return writeAPIErrorCode(c, fiber.StatusNotFound, "module_version_not_found", "Module Version not found")
			}
		}
		members, err := metadata.VersionSkills(c.Context(), modulePath, version)
		if err != nil {
			return writeModuleSkillError(c, err)
		}
		var member *catalog.VersionSkill
		for index := range members {
			if members[index].Path == skillPath {
				member = &members[index]
				break
			}
		}
		if member == nil {
			return writeAPIErrorCode(c, fiber.StatusNotFound, "skill_not_found", "Skill not found")
		}
		content, err := contents.SkillContent(c.Context(), modulePath, version, skillPath)
		if err != nil {
			return writeModuleSkillError(c, err)
		}
		if query.Movable() {
			c.Set(fiber.HeaderCacheControl, "no-cache, no-store, must-revalidate")
		} else {
			c.Set(fiber.HeaderCacheControl, "public, max-age=31536000, immutable")
		}
		return writeJSON(c, fiber.StatusOK, protocolapi.ModuleVersionSkill{
			ModulePath: modulePath, Version: version, Time: identity.CommitTime, ArchiveSize: identity.ArchiveSize,
			Name: member.Name, Path: member.Path, Description: member.Description, Content: string(content),
		})
	}
}

func writeModuleSkillError(c fiber.Ctx, err error) error {
	status := huberrors.Kind(err)
	if status < 400 || status > 599 {
		status = fiber.StatusInternalServerError
	}
	if status >= 500 {
		return writeInternalAPIError(c, "module.skill", status, "module_skill_failed", "Module Version Skill failed", err)
	}
	return writeAPIErrorCode(c, status, "module_skill_failed", fmt.Sprintf("Module Version Skill failed: %v", err))
}
