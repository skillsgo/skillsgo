CREATE TABLE provider_sync_leases (
  job_name TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  fencing_token BIGINT NOT NULL DEFAULT 0,
  lease_expires_at TIMESTAMPTZ NOT NULL,
  heartbeat_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE provider_crawls (
  crawl_id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  scheduled_window TIMESTAMPTZ NOT NULL,
  fencing_token BIGINT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'failed')),
  expected_pages INTEGER NOT NULL DEFAULT 0,
  completed_pages INTEGER NOT NULL DEFAULT 0,
  failure TEXT NOT NULL DEFAULT '',
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  UNIQUE(provider, scheduled_window)
);
CREATE TABLE provider_crawl_pages (
  crawl_id TEXT NOT NULL REFERENCES provider_crawls(crawl_id) ON DELETE CASCADE,
  page INTEGER NOT NULL,
  fencing_token BIGINT NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY(crawl_id, page)
);
CREATE TABLE provider_skill_observations (
  crawl_id TEXT NOT NULL REFERENCES provider_crawls(crawl_id) ON DELETE CASCADE,
  skill_id TEXT NOT NULL,
  source TEXT NOT NULL,
  slug TEXT NOT NULL,
  installs BIGINT NOT NULL CHECK (installs >= 0),
  observed_at TIMESTAMPTZ NOT NULL,
  fencing_token BIGINT NOT NULL,
  PRIMARY KEY(crawl_id, skill_id)
);
