/*
 * [INPUT]: Depends on strict Repository resolution requests, the shared typed Selector grammar, the create-only Repository Publisher, committed Catalog release Info, and Fiber routing.
 * [OUTPUT]: Provides POST /api/v1/repository-resolutions, resolving add-time Tags/branches/commits once and returning only canonical immutable Repository identity.
 * [POS]: Serves as the mutable product API boundary kept deliberately separate from immutable root Repository Proxy resources.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type repositoryResolver interface {
	ResolveRepository(context.Context, string, string) (protocolapi.RepositoryInfo, error)
}

type publishedRepositoryResolver struct {
	metadata     *catalog.Catalog
	materializer repositoryMaterializer
}

func (resolver publishedRepositoryResolver) ResolveRepository(ctx context.Context, repositoryID, selector string) (protocolapi.RepositoryInfo, error) {
	version, err := resolver.materializer.Materialize(ctx, repositoryID, selector)
	if err != nil {
		return protocolapi.RepositoryInfo{}, err
	}
	encoded, found, err := resolver.metadata.RepositoryReleaseInfo(ctx, repositoryID, version)
	if err != nil {
		return protocolapi.RepositoryInfo{}, err
	}
	if !found {
		return protocolapi.RepositoryInfo{}, fmt.Errorf("resolved Repository publication is not visible for %s@%s", repositoryID, version)
	}
	var info protocolapi.RepositoryInfo
	if err := json.Unmarshal(encoded, &info); err != nil {
		return protocolapi.RepositoryInfo{}, fmt.Errorf("decode committed Repository Info: %w", err)
	}
	return info, nil
}

func registerRepositoryResolutionRoute(router fiber.Router, resolver repositoryResolver) {
	router.Post("/api/v1/repository-resolutions", repositoryResolutionHandler(resolver))
}

func repositoryResolutionHandler(resolver repositoryResolver) fiber.Handler {
	return func(c fiber.Ctx) error {
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		var request protocolapi.RepositoryResolutionRequest
		if err := decoder.Decode(&request); err != nil {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_repository_resolution", "invalid Repository resolution request")
		}
		if err := ensureJSONEOF(decoder); err != nil || request.SchemaVersion != protocolapi.SchemaVersion {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_repository_resolution", "invalid Repository resolution request")
		}
		if err := validateRepositoryResource(request.RepositoryID); err != nil {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_repository_id", "repositoryId must be canonical")
		}
		selector, err := protocolversion.ParseSelector(request.Selector)
		if err != nil {
			return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_repository_selector", err.Error())
		}
		info, err := resolver.ResolveRepository(c.Context(), request.RepositoryID, selector.Value)
		if err != nil {
			status := huberrors.Kind(err)
			if status < 400 || status > 599 {
				status = fiber.StatusInternalServerError
			}
			if status >= 500 {
				return writeInternalAPIError(c, "repository.resolve", status, "repository_resolution_failed", "Repository resolution failed", err)
			}
			return writeAPIErrorCode(c, status, "repository_resolution_failed", "Repository revision could not be resolved")
		}
		if info.ID != request.RepositoryID || !protocolversion.IsImmutable(info.Version) || info.Time.IsZero() || info.Ref == "" || info.CommitSHA == "" {
			return writeInternalAPIError(c, "repository.resolve", fiber.StatusInternalServerError, "invalid_repository_resolution", "Repository resolution failed", fmt.Errorf("resolver returned invalid immutable Repository Info"))
		}
		return writeJSON(c, fiber.StatusOK, protocolapi.RepositoryResolutionResponse{
			SchemaVersion: protocolapi.SchemaVersion, RepositoryID: info.ID, Version: info.Version,
			Time: info.Time, Ref: info.Ref, CommitSHA: info.CommitSHA,
		})
	}
}

func ensureJSONEOF(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		if err == nil {
			return fmt.Errorf("multiple JSON values")
		}
		return err
	}
	return nil
}
