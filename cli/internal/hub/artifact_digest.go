/*
 * [INPUT]: Depends on immutable Repository ZIP bytes, canonical Repository coordinates, resolved versions, and the shared h1 contract.
 * [OUTPUT]: Provides Repository h1 verification over the shared artifact implementation.
 * [POS]: Serves as the CLI integrity boundary binding Package Info to downloaded artifact bytes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"fmt"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func VerifyPackageSum(data []byte, packagePath, version, expected string) error {
	actual, err := protocolartifact.PackageSum(data, packagePath, version)
	if err != nil {
		return err
	}
	if actual != expected {
		return fmt.Errorf("Hub Repository Sum mismatch for %s@%s: %s != %s", packagePath, version, actual, expected)
	}
	return nil
}
