/*
 * [INPUT]: Depends on an exact immutable Package coordinate and Sum, the disposable Info cache, and the Hub client for cache misses.
 * [OUTPUT]: Provides read-through exact Package metadata and verified Git-tree content without exposing cache layout to consumers.
 * [POS]: Serves as the single dependency acquisition boundary shared by local command and inventory capabilities.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packageprovider

import (
	"context"
	"fmt"
	"os"
	"sync"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

type LockedPackage struct {
	PackagePath string
	Version     string
	Sum         string
}

type Provider struct {
	Client *hub.Client
	Info   infocache.Cache
}

var metadataFlights sync.Map

func (p Provider) Metadata(ctx context.Context, locked LockedPackage) (*hub.PackageResource, error) {
	if err := validateLocked(locked); err != nil {
		return nil, err
	}
	key := locked.PackagePath + "\x00" + locked.Version
	value, _ := metadataFlights.LoadOrStore(key, &sync.Mutex{})
	flight := value.(*sync.Mutex)
	flight.Lock()
	defer flight.Unlock()

	if bytes, err := p.Info.Get(locked.PackagePath, locked.Version, "package.info"); err == nil {
		if resource, parseErr := parseLocked(locked, bytes); parseErr == nil {
			return resource, nil
		}
	}
	if p.Client == nil {
		return nil, fmt.Errorf("Package metadata cache miss for %s@%s and no Hub is available", locked.PackagePath, locked.Version)
	}
	resource, err := p.Client.Package(ctx, locked.PackagePath, locked.Version)
	if err != nil {
		return nil, fmt.Errorf("restore Package metadata %s@%s: %w", locked.PackagePath, locked.Version, err)
	}
	if err := validateResource(locked, resource); err != nil {
		return nil, err
	}
	if err := p.Info.Replace(locked.PackagePath, locked.Version, "package.info", resource.InfoBytes); err != nil {
		return nil, fmt.Errorf("publish rebuilt Package metadata cache: %w", err)
	}
	return resource, nil
}

func (p Provider) Content(ctx context.Context, locked LockedPackage, progress func(int64, int64)) (*hub.PackageResource, error) {
	resource, err := p.Metadata(ctx, locked)
	if err != nil {
		return nil, err
	}
	if p.Client == nil {
		return nil, fmt.Errorf("Package content cache miss for %s@%s and no Hub is available", locked.PackagePath, locked.Version)
	}
	entries, err := p.Client.FetchPackageEntries(ctx, resource, progress)
	if err != nil {
		return nil, fmt.Errorf("restore Package content %s@%s: %w", locked.PackagePath, locked.Version, err)
	}
	actual, err := protocolartifact.PackageEntriesSum(entries, locked.PackagePath, locked.Version)
	if err != nil || actual != locked.Sum {
		return nil, fmt.Errorf("restored Package %s@%s conflicts with skills-lock.yaml", locked.PackagePath, locked.Version)
	}
	resource.Entries = entries
	return resource, nil
}

func parseLocked(locked LockedPackage, bytes []byte) (*hub.PackageResource, error) {
	resource, err := hub.ParsePackageInfo(locked.PackagePath, bytes)
	if err != nil {
		return nil, err
	}
	if err := validateResource(locked, resource); err != nil {
		return nil, err
	}
	return resource, nil
}

func validateLocked(locked LockedPackage) error {
	if locked.PackagePath == "" || locked.Version == "" || !protocolartifact.ValidSum(locked.Sum) {
		return fmt.Errorf("incomplete locked Package coordinate")
	}
	return nil
}

func validateResource(locked LockedPackage, resource *hub.PackageResource) error {
	if resource == nil || resource.Info.PackagePath != locked.PackagePath || resource.Info.Version != locked.Version || resource.Info.Sum != locked.Sum {
		return fmt.Errorf("Package metadata %s@%s conflicts with skills-lock.yaml", locked.PackagePath, locked.Version)
	}
	return nil
}

func Default(home string, client *hub.Client) Provider {
	if home == "" {
		home, _ = os.UserHomeDir()
	}
	return Provider{Client: client, Info: infocache.Cache{Root: infocache.DefaultRoot(home)}}
}
