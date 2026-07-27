/*
 * [INPUT]: Depends on the shared storage compliance suite and either Azurite test settings or real Azure Blob credentials.
 * [OUTPUT]: Specifies Azure Blob backend compliance against an explicitly configured test service.
 * [POS]: Serves as emulator-friendly integration coverage for the Azure Blob storage adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/Azure/azure-storage-blob-go/azblob"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/compliance"
	"github.com/technosophos/moniker"
)

func TestBackend(t *testing.T) {
	backend := getStorage(t)
	defer backend.client.containerURL.Delete(t.Context(), azblob.ContainerAccessConditions{})
	compliance.RunTests(t, backend, backend.clear)
}

func BenchmarkBackend(b *testing.B) {
	backend := getStorage(b)
	defer backend.client.containerURL.Delete(b.Context(), azblob.ContainerAccessConditions{})
	compliance.RunBenchmarks(b, backend, backend.clear)
}

func (s *Storage) clear() error {
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()

	for marker := (azblob.Marker{}); marker.NotDone(); {
		listBlob, err := s.client.containerURL.ListBlobsFlatSegment(ctx, marker, azblob.ListBlobsSegmentOptions{})
		if err != nil {
			return err
		}
		marker = listBlob.NextMarker

		for _, blob := range listBlob.Segment.BlobItems {

			blobURL := s.client.containerURL.NewBlockBlobURL(blob.Name)
			_, err := blobURL.Delete(ctx, azblob.DeleteSnapshotsOptionNone, azblob.BlobAccessConditions{})
			if err != nil {
				return err
			}
		}
	}

	return nil
}

func getStorage(t testing.TB) *Storage {
	t.Helper()
	containerName := randomContainerName(os.Getenv("GA_PULL_REQUEST"))
	cfg := getTestConfig(containerName)
	if cfg == nil {
		t.SkipNow()
	}

	var s *Storage
	var err error
	if endpoint := os.Getenv("SKILLSGO_TEST_AZURE_BLOB_ENDPOINT"); endpoint != "" {
		accountURL, parseErr := url.Parse(endpoint)
		if parseErr != nil {
			t.Fatal(parseErr)
		}
		client, clientErr := newBlobStoreClient(accountURL, cfg.AccountName, cfg.AccountKey, "", "", containerName)
		if clientErr != nil {
			t.Fatal(clientErr)
		}
		s = &Storage{client: client, timeout: 30 * time.Second}
	} else {
		s, err = New(cfg, config.GetTimeoutDuration(30))
	}
	if err != nil {
		t.Fatal(err)
	}
	_, err = s.client.containerURL.Create(t.Context(), azblob.Metadata{}, azblob.PublicAccessNone)
	if err != nil {
		t.Fatal(err)
	}

	return s
}

func getTestConfig(containerName string) *config.AzureBlobConfig {
	key := os.Getenv("SKILLSGO_TEST_AZURE_ACCOUNT_KEY")
	name := os.Getenv("SKILLSGO_TEST_AZURE_ACCOUNT_NAME")
	if key != "" && name != "" {
		return &config.AzureBlobConfig{AccountName: name, AccountKey: key, ContainerName: containerName}
	}

	key = os.Getenv("SKILLSGO_HUB_AZURE_ACCOUNT_KEY")
	resourceId := os.Getenv("SKILLSGO_HUB_AZURE_MANAGED_IDENTITY_RESOURCE_ID")
	credentialScope := os.Getenv("SKILLSGO_HUB_AZURE_CREDENTIAL_SCOPE")
	if key == "" && (resourceId == "" || credentialScope == "") {
		return nil
	}
	name = os.Getenv("SKILLSGO_HUB_AZURE_ACCOUNT_NAME")
	if name == "" {
		return nil
	}
	return &config.AzureBlobConfig{
		AccountName:               name,
		AccountKey:                key,
		ManagedIdentityResourceID: resourceId,
		CredentialScope:           credentialScope,
		ContainerName:             containerName,
	}
}

func randomContainerName(prefix string) string {
	// moniker is a cool library to produce mostly unique, human-readable names
	// see https://github.com/technosophos/moniker for more details
	namer := moniker.New()
	if prefix != "" {
		return fmt.Sprintf("%s_%s", prefix, namer.NameSep(""))
	}
	return namer.NameSep("")
}
