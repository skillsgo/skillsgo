ALTER TABLE versions
  ADD COLUMN package_size_bytes BIGINT NOT NULL DEFAULT 0,
  ADD CONSTRAINT versions_package_size_nonnegative CHECK (package_size_bytes >= 0);

COMMENT ON COLUMN versions.package_size_bytes IS 'Uncompressed byte size of the normalized immutable Package Artifact tree.';
