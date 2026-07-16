/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by azureblob.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// AzureBlobConfig specifies the properties required to use Azure as the storage backend.
type AzureBlobConfig struct {
	AccountName               string `envconfig:"SKILLSGO_HUB_AZURE_ACCOUNT_NAME"                 validate:"required"`
	AccountKey                string `envconfig:"SKILLSGO_HUB_AZURE_ACCOUNT_KEY"`
	ManagedIdentityResourceID string `envconfig:"SKILLSGO_HUB_AZURE_MANAGED_IDENTITY_RESOURCE_ID"`
	CredentialScope           string `envconfig:"SKILLSGO_HUB_AZURE_CREDENTIAL_SCOPE"`
	ContainerName             string `envconfig:"SKILLSGO_HUB_AZURE_CONTAINER_NAME"               validate:"required"`
}
