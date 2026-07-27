/*
 * [INPUT]: Depends on every provider-specific Hub artifact storage configuration.
 * [OUTPUT]: Provides the aggregate storage configuration decoded from YAML and environment variables.
 * [POS]: Serves as the provider configuration registry in the config package.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// Storage provides configs for various storage backends.
type Storage struct {
	Disk      *DiskConfig
	GCP       *GCPConfig
	S3        *S3Config
	R2        *R2Config
	AzureBlob *AzureBlobConfig
}
