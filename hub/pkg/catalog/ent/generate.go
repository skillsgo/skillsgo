/*
 * [INPUT]: Depends on Ent's code generator and the schema definitions in the sibling schema package.
 * [OUTPUT]: Provides the reproducible go:generate entry point for Catalog entity code.
 * [POS]: Serves as the generated persistence-client boundary for the Hub Catalog module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package ent

//go:generate go run entgo.io/ent/cmd/ent generate --feature sql/upsert,sql/versioned-migration ./schema
