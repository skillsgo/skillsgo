/*
 * [INPUT]: Depends on fully resolved current and desired Package trees, caller-selected Projection state, immutable Info cache identity, and optional Workspace manifest/lock publication.
 * [OUTPUT]: Provides shared direct-Projection reconcile preparation plus the ordinary commit wrapper for Projections, immutable Info, manifest, and lock mutations.
 * [POS]: Serves as the command-internal desired-state engine shared by add, update, install, and adopt-through-add without owning their user intent or interaction policy.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"fmt"
	"sort"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/packagemutation"
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

type packageCoordinateState struct {
	resource    *hub.PackageResource
	entries     []protocolartifact.Entry
	projections []packagestore.Projection
	sum         string
}

type packageReconcileRequest struct {
	packagePath      string
	packagesRoot     string
	infoRoot         string
	desired          packageCoordinateState
	current          *packageCoordinateState
	workspace        *packagemutation.WorkspaceState
	replaceConflicts bool
	operation        string
}

func preparePackageReconcile(request packageReconcileRequest) (packagemutation.Plan, error) {
	if request.desired.resource == nil {
		return packagemutation.Plan{}, fmt.Errorf("Package reconcile requires a desired Package resource")
	}
	desired := request.desired.resource
	desiredMembers := packageMemberPaths(desired)
	desiredTransaction, err := packagestore.Prepare(packagestore.Options{
		PackagesRoot:       request.packagesRoot,
		PackagePath:        request.packagePath,
		Version:            desired.Info.Version,
		Entries:            request.desired.entries,
		Sum:                packageCoordinateSum(request.desired),
		Members:            desiredMembers,
		SkillNames:         packageSkillNames(desired.Members),
		Projections:        request.desired.projections,
		ReplaceConflicts:   request.replaceConflicts,
		PreviousSkillNames: previousPackageSkillNames(request.current),
	})
	if err != nil {
		return packagemutation.Plan{}, err
	}
	transactions := []packagemutation.Transaction{desiredTransaction}
	if request.current != nil && request.current.resource != nil && request.current.resource.Info.Version != desired.Info.Version {
		current := request.current.resource
		removalTransaction, prepareErr := packagestore.Prepare(packagestore.Options{
			PackagesRoot:       request.packagesRoot,
			PackagePath:        request.packagePath,
			Version:            current.Info.Version,
			Entries:            request.current.entries,
			Sum:                packageCoordinateSum(*request.current),
			Members:            packageMemberPaths(current),
			SkillNames:         packageSkillNames(current.Members),
			RemovedProjections: legacyOnlyProjections(request.current.projections),
			RemovePackage:      true,
			ReplaceConflicts:   request.replaceConflicts,
		})
		if prepareErr != nil {
			_ = desiredTransaction.Rollback()
			return packagemutation.Plan{}, prepareErr
		}
		transactions = append(transactions, removalTransaction)
	}
	plan := packagemutation.Plan{
		Transactions: transactions,
		Workspace:    request.workspace,
		Operation:    request.operation,
	}
	if len(desired.InfoBytes) > 0 && request.infoRoot != "" {
		plan.ImmutableInfo = []packagemutation.ImmutableInfo{{
			Cache:       infocache.Cache{Root: request.infoRoot},
			PackagePath: request.packagePath,
			Version:     desired.Info.Version,
			Kind:        "package.info",
			Bytes:       desired.InfoBytes,
		}}
	}
	return plan, nil
}

func reconcilePackage(request packageReconcileRequest) error {
	plan, err := preparePackageReconcile(request)
	if err != nil {
		return err
	}
	return plan.Commit()
}

func packageMemberPaths(resource *hub.PackageResource) []string {
	paths := make([]string, 0, len(resource.Members))
	for _, member := range resource.Members {
		paths = append(paths, member.Info.Path)
	}
	sort.Strings(paths)
	return paths
}

func previousPackageSkillNames(current *packageCoordinateState) map[string]string {
	if current == nil || current.resource == nil || current.resource.Info.Version == "" {
		return nil
	}
	return packageSkillNames(current.resource.Members)
}

func packageCoordinateSum(state packageCoordinateState) string {
	if state.sum != "" {
		return state.sum
	}
	return state.resource.Info.Sum
}
