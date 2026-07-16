/*
 * [INPUT]: Depends on the s3 package imports and contracts declared in this file.
 * [OUTPUT]: Provides the s3 package behavior implemented by doc.go.
 * [POS]: Serves as maintained source in the s3 package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
/*
Package s3 provides a storage driver to upload module files to
amazon s3 storage bucket.

# Configuration

Environment variables:

	AWS_REGION				// region for this storage, e.g 'us-west-2'
	AWS_ACCESS_KEY_ID
	AWS_SECRET_ACCESS_KEY
	AWS_SESSION_TOKEN		// [optional]
	AWS_FORCE_PATH_STYLE	// [optional]
	SKILLSGO_HUB_S3_BUCKET_NAME

For information how to get your keyId and access key turn to official aws docs: https://docs.aws.amazon.com/sdk-for-go/v1/developer-guide/setting-up.html

Example:

	Bash:
		export AWS_REGION="us-west-2"
	Fish:
		set -x AWS_REGION us-west-2
*/
package s3
