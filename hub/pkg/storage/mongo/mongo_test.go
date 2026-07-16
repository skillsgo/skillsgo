/*
 * [INPUT]: Depends on the mongo package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the mongo package behavior covered by mongo_test.go.
 * [POS]: Serves as test coverage for the mongo package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mongo

import (
	"bytes"
	"context"
	"io"
	"os"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/compliance"
	"github.com/stretchr/testify/require"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

func TestBackend(t *testing.T) {
	backend := getStorage(t)
	compliance.RunTests(t, backend, backend.clear)
}

func (s *SkillStore) clear() error {
	s.client.Database(s.db).Drop(context.Background())
	return nil
}

func BenchmarkBackend(b *testing.B) {
	backend := getStorage(b)
	compliance.RunBenchmarks(b, backend, backend.clear)
}

func getStorage(tb testing.TB) *SkillStore {
	url := os.Getenv("SKILLSGO_HUB_MONGO_STORAGE_URL")

	if url == "" {
		tb.SkipNow()
	}

	backend, err := NewStorage(&config.MongoConfig{URL: url}, config.GetTimeoutDuration(300))
	require.NoError(tb, err)

	return backend
}

func TestQueryModuleVersionExists(t *testing.T) {
	modname, ver := "getTestModule", "v1.2.3"
	mock := &storage.Version{
		Info:     []byte("123"),
		Manifest: []byte("456"),
		Zip:      io.NopCloser(bytes.NewReader([]byte("789"))),
	}

	ctx := t.Context()
	backend := getStorage(t)

	zipBts, _ := io.ReadAll(mock.Zip)
	backend.Save(ctx, modname, ver, mock.Manifest, bytes.NewReader(zipBts), mock.ZipMD5, mock.Info)
	defer backend.Delete(ctx, modname, ver)

	info, err := query(ctx, backend, modname, ver)
	require.NoError(t, err)
	require.Equal(t, mock.Info, info.Info)
	require.Equal(t, mock.Manifest, info.Manifest)
}

func TestQueryKindNotFoundErrorCases(t *testing.T) {
	modname, ver := "getTestModule", "v1.2.3"
	mock := &storage.Version{
		Info:     []byte("123"),
		Manifest: []byte("456"),
		Zip:      io.NopCloser(bytes.NewReader([]byte("789"))),
	}

	ctx := t.Context()
	backend := getStorage(t)

	zipBts, _ := io.ReadAll(mock.Zip)
	backend.Save(ctx, modname, ver, mock.Manifest, bytes.NewReader(zipBts), nil, mock.Info)
	defer backend.Delete(ctx, modname, ver)

	testCases := []struct {
		modname string
		ver     string
	}{
		{"getTestModule", "yyy"}, // test NotFound non-existent version
		{"getTestModule", ""},    // test NotFound empty str version
		{"xxx", "v1.2.3"},        // test NotFound non-existent module
		{"", "v1.2.3"},           // test NotFound empty str module
		{"", ""},                 // test NotFound empty str module and version
		{"xxx", "yyy"},           // test NotFound non-existent module and version
	}

	for _, test := range testCases {
		_, err := query(ctx, backend, test.modname, test.ver)
		require.Error(t, err)
		require.Equal(t, errors.KindNotFound, errors.Kind(err))
	}
}

func TestQueryKindUnexpectedErrorCases(t *testing.T) {
	// Prepare error documents
	// If there is any error in preparation phase, skip this test
	mongoStorage := getStorage(t)
	uri := os.Getenv("SKILLSGO_HUB_MONGO_STORAGE_URL")
	client, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		t.SkipNow()
	}
	defer client.Disconnect(t.Context())
	coll := client.Database("athens").Collection("skills")
	errDocs := []struct {
		Skill    string `bson:"skill"`
		Version  string `bson:"version"`
		Manifest any    `bson:"manifest"`
		Info     any    `bson:"info"`
	}{
		{"model1", "v1.1.1", 12345678, "error document with integer mod"},
		{"model2", "v2.0.0", true, "error document with boolean mod"},
	}
	// In case some docs were inserted into the collection before, using upsert instead.
	for _, errDoc := range errDocs {
		filter := bson.D{{"skill", errDoc.Skill}, {"version", errDoc.Version}}
		update := bson.D{{"$set", bson.D{{"manifest", errDoc.Manifest}, {"info", errDoc.Info}}}}
		opts := options.UpdateOne().SetUpsert(true).SetBypassDocumentValidation(true)
		_, err = coll.UpdateOne(t.Context(), filter, update, opts)
		if err != nil {
			t.SkipNow()
		}
	}
	testCases := []struct {
		modName string
		version string
	}{
		{"model1", "v1.1.1"}, // test case: decode integer to []byte
		{"model2", "v2.0.0"}, // test case: decode boolean to []byte
	}
	for _, test := range testCases {
		_, err := query(t.Context(), mongoStorage, test.modName, test.version)
		require.Error(t, err)
		require.Equal(t, errors.KindUnexpected, errors.Kind(err))
	}
}

func TestNewStorageWithDefaultOverrides(t *testing.T) {
	url := os.Getenv("SKILLSGO_HUB_MONGO_STORAGE_URL")

	if url == "" {
		t.SkipNow()
	}

	testCases := []struct {
		name        string
		dbName      string
		expDbName   string
		collName    string
		expCollName string
	}{
		{"Test Default 'Athens' DB Name", "athens", "athens", "skills", "skills"},
		{"Test Custom DB Name", "testAthens", "testAthens", "skills", "skills"},
		{"Test Blank DB Name", "", "athens", "skills", "skills"},
		{"Test Default 'Skills' Collection Name", "athens", "athens", "skills", "skills"},
		{"Test Custom Collection Name", "athens", "athens", "testModules", "testModules"}, // Tests the non-default collection name
		{"Test Blank Collection Name", "athens", "athens", "", "skills"},
	}

	for _, test := range testCases {
		t.Run(test.name, func(t *testing.T) {
			backend, err := NewStorage(&config.MongoConfig{URL: url, DefaultDBName: test.dbName, DefaultCollectionName: test.collName}, config.GetTimeoutDuration(300))
			require.NoError(t, err)
			require.Equal(t, test.expDbName, backend.db)
			require.Equal(t, test.expCollName, backend.coll)
		})
	}
}

func TestMongoConfigVerification(t *testing.T) {
	testCases := []struct {
		testName     string
		url          string
		requireError bool
	}{
		{"Test Invalid Configuration:Empty URL", "", true},                         // test mongo configuration without url
		{"Test InValid Configuration:Misconfigured URL Scheme", "127.0.0.1", true}, // test mongo configuration with misconfigured url
		{"Test Valid Configuration: Full URL", "mongodb://127.0.0.1", false},       // test mongo configuration with url
	}

	for _, test := range testCases {
		t.Run(test.testName, func(t *testing.T) {
			backend := &SkillStore{url: test.url, timeout: config.GetTimeoutDuration(300)}
			_, err := backend.newClient()
			if test.requireError {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
			}
		})
	}
}
