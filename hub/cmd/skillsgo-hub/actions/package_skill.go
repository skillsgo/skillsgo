/*
 * [INPUT]: Depends on canonical Package paths, Version Query parsing, demand publication, digest-bearing Skill rows, content-addressed source/localized Markdown storage, and Fiber routing.
 * [OUTPUT]: Provides GET /api/v1/{packagePath}/versions/{version}/skills?path={path}[&lang={lang}] with digest-resolved source or localized display content.
 * [POS]: Serves as the version-scoped Skill member projection over immutable Package metadata, ZIP distribution, and global presentation localizations.
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
	"github.com/skillsgo/skillsgo/hub/pkg/presentation"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

func registerPackageSkillRoute(router fiber.Router, metadata *catalog.Catalog, materializer repositoryMaterializer, contents storage.SkillContentStore) {
	router.Get("/api/v1/+/versions/:version/skills", moduleSkillHandler(metadata, materializer, contents))
}

func moduleSkillHandler(metadata *catalog.Catalog, materializer repositoryMaterializer, contents storage.SkillContentStore) fiber.Handler {
	return func(c fiber.Ctx) error {
		packagePath, err := paths.GetSkill(c.Path())
		if err != nil || validatePackageResource(packagePath) != nil {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_package_path", "packagePath must be canonical")
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
			version, err = materializer.Materialize(c.Context(), packagePath, query.Value)
			if err != nil {
				return writePackageSkillError(c, err)
			}
		}
		identity, found, err := metadata.PackageVersionByCoordinate(c.Context(), packagePath, version)
		if err != nil {
			return writePackageSkillError(c, err)
		}
		if !found {
			version, err = materializer.Materialize(c.Context(), packagePath, query.Value)
			if err != nil {
				return writePackageSkillError(c, err)
			}
			identity, found, err = metadata.PackageVersionByCoordinate(c.Context(), packagePath, version)
			if err != nil {
				return writePackageSkillError(c, err)
			}
			if !found {
				return writeAPIErrorCode(c, fiber.StatusNotFound, "module_version_not_found", "Package Version not found")
			}
		}
		members, err := metadata.VersionSkills(c.Context(), packagePath, version)
		if err != nil {
			return writePackageSkillError(c, err)
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
		content, err := contents.SkillContent(c.Context(), member.DocumentDigest)
		if err != nil {
			return writePackageSkillError(c, err)
		}
		description := member.Description
		lang := strings.TrimSpace(c.Query("lang"))
		if lang != "" {
			lang, err = presentation.CanonicalLang(lang)
			if err != nil {
				return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_lang", err.Error())
			}
			if localized, ok, lookupErr := metadata.LocalizedVersionSkill(c.Context(), packagePath, version, skillPath, catalog.LocalizedSkill, lang); lookupErr == nil && ok && localized.SourceDigest == member.DescriptionDigest && localized.ResultKind == catalog.LocalizationTranslated {
				description = localized.Text
			}
			if localized, ok, lookupErr := metadata.LocalizedVersionSkill(c.Context(), packagePath, version, skillPath, catalog.LocalizedSkillDocument, lang); lookupErr == nil && ok && localized.SourceDigest == member.DocumentDigest && localized.ResultKind == catalog.LocalizationTranslated {
				if translated, readErr := contents.LocalizedSkillContent(c.Context(), member.DocumentDigest, localized.PromptVersion, lang); readErr == nil {
					content = translated
				}
			}
		}
		if query.Movable() || lang != "" {
			c.Set(fiber.HeaderCacheControl, "no-cache, no-store, must-revalidate")
		} else {
			c.Set(fiber.HeaderCacheControl, "public, max-age=31536000, immutable")
		}
		return writeJSON(c, fiber.StatusOK, protocolapi.PackageVersionSkill{
			PackagePath: packagePath, Version: version, Time: identity.CommitTime, ArchiveSize: identity.ArchiveSize,
			Name: member.Name, Path: member.Path, Description: description, Content: string(content),
		})
	}
}

func writePackageSkillError(c fiber.Ctx, err error) error {
	status := huberrors.Kind(err)
	if status < 400 || status > 599 {
		status = fiber.StatusInternalServerError
	}
	if status >= 500 {
		return writeInternalAPIError(c, "module.skill", status, "package_skill_failed", "Package Version Skill failed", err)
	}
	return writeAPIErrorCode(c, status, "package_skill_failed", fmt.Sprintf("Package Version Skill failed: %v", err))
}
