-- atlas:delimiter \nGO
-- [INPUT]: Depends on the SQLite skills table and coordinate-based external-content FTS index.
-- [OUTPUT]: Renames the public Skill identifier column to skill_id and rebuilds FTS synchronization against that column.
-- [POS]: Serves as the additive Catalog migration from Skill Coordinate to public Skill ID terminology.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
DROP TRIGGER skills_fts_insert;
DROP TRIGGER skills_fts_delete;
DROP TRIGGER skills_fts_update;
DROP TABLE skills_fts;
ALTER TABLE skills RENAME COLUMN coordinate TO skill_id;
CREATE VIRTUAL TABLE skills_fts USING fts5(name, description, skill_id, content='skills', content_rowid='id', tokenize='trigram');
INSERT INTO skills_fts(skills_fts) VALUES('rebuild');
CREATE TRIGGER skills_fts_insert AFTER INSERT ON skills BEGIN
  INSERT INTO skills_fts(rowid,name,description,skill_id) VALUES(new.id,new.name,new.description,new.skill_id);
END;
GO
CREATE TRIGGER skills_fts_delete AFTER DELETE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description,skill_id) VALUES('delete',old.id,old.name,old.description,old.skill_id);
END;
GO
CREATE TRIGGER skills_fts_update AFTER UPDATE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description,skill_id) VALUES('delete',old.id,old.name,old.description,old.skill_id);
  INSERT INTO skills_fts(rowid,name,description,skill_id) VALUES(new.id,new.name,new.description,new.skill_id);
END;
GO
