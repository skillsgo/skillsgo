-- [INPUT]: Depends on the Hub business schema and globally shared PostgreSQL time-aware state.
-- [OUTPUT]: Adds durable translation-provider admission state for multi-instance payment-failure circuit breaking.
-- [POS]: Serves as the shared cost-safety coordination state for Hub translation workers.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

CREATE TABLE translation_provider_admissions (
  provider TEXT PRIMARY KEY,
  failure_kind TEXT NOT NULL,
  blocked_until TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT translation_provider_admissions_provider_check CHECK (trim(provider) <> ''),
  CONSTRAINT translation_provider_admissions_failure_kind_check CHECK (trim(failure_kind) <> '')
);
