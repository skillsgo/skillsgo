/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by s3.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// S3Config specifies the properties required to use S3 as the storage backend.
type S3Config struct {
	Region                             string `envconfig:"AWS_REGION"                             validate:"required"`
	Key                                string `envconfig:"AWS_ACCESS_KEY_ID"`
	Secret                             string `envconfig:"AWS_SECRET_ACCESS_KEY"`
	Token                              string `envconfig:"AWS_SESSION_TOKEN"`
	Bucket                             string `envconfig:"SKILLSGO_HUB_S3_BUCKET_NAME"                  validate:"required"`
	UseDefaultConfiguration            bool   `envconfig:"AWS_USE_DEFAULT_CONFIGURATION"`
	ForcePathStyle                     bool   `envconfig:"AWS_FORCE_PATH_STYLE"`
	CredentialsEndpoint                string `envconfig:"AWS_CREDENTIALS_ENDPOINT"`
	AwsContainerCredentialsRelativeURI string `envconfig:"AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"`
	Endpoint                           string `envconfig:"AWS_ENDPOINT"`
}
