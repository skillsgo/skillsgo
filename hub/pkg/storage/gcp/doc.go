/*
 * [INPUT]: Depends on the gcp package imports and contracts declared in this file.
 * [OUTPUT]: Provides the gcp package behavior implemented by doc.go.
 * [POS]: Serves as maintained source in the gcp package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
/*
Package gcp provides a storage driver to upload module files to a google
cloud platform storage bucket.

# Configuration

Environment variables:

	SKILLSGO_HUB_STORAGE_GCP_BUCKET	// full name of storage bucket
	SKILLSGO_HUB_STORAGE_GCP_SA		// path to json keyfile of a service account

Example:

	Bash:
		export SKILLSGO_HUB_STORAGE_GCP_BUCKET="fancy-pony-33928.appspot.com"
	Fish:
		set -x SKILLSGO_HUB_STORAGE_GCP_BUCKET fancy-pony-339288.appspot.com
*/
package gcp
