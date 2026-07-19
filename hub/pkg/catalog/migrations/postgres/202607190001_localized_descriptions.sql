CREATE TABLE localized_descriptions (
    id BIGSERIAL PRIMARY KEY,
    resource_kind TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    locale TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    source_digest TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (resource_kind, resource_id, locale)
);
