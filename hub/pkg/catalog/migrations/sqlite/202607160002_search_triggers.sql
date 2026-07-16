-- atlas:delimiter \nGO
-- [INPUT]: Depends on the SQLite skills table and external-content skills_fts virtual table.
-- [OUTPUT]: Provides insert, update, and delete synchronization triggers for Catalog search.
-- [POS]: Serves as the SQLite FTS synchronization migration for the Hub Catalog.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE TRIGGER skills_fts_insert AFTER INSERT ON skills BEGIN
  INSERT INTO skills_fts(rowid,name,description,coordinate) VALUES(new.id,new.name,new.description,new.coordinate);
END;
GO
CREATE TRIGGER skills_fts_delete AFTER DELETE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description,coordinate) VALUES('delete',old.id,old.name,old.description,old.coordinate);
END;
GO
CREATE TRIGGER skills_fts_update AFTER UPDATE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description,coordinate) VALUES('delete',old.id,old.name,old.description,old.coordinate);
  INSERT INTO skills_fts(rowid,name,description,coordinate) VALUES(new.id,new.name,new.description,new.coordinate);
END;
GO
