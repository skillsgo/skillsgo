/*
 * [INPUT]: Depends on the addons package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the addons package behavior covered by with_pool_test.go.
 * [POS]: Serves as test coverage for the addons package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package addons

import (
	"bytes"
	"context"
	"fmt"
	"reflect"
	"sync"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

// TestPoolLogic ensures that no
// more than given workers are working
// at one time.
func TestPoolLogic(t *testing.T) {
	m := &mockPool{}
	workers := 5
	dp := WithPool(workers)(m)
	m.ch = make(chan struct{})
	for range 10 {
		go dp.List(t.Context(), "")
	}
	<-m.ch
	if m.num != workers {
		t.Fatalf("expected %d workers but got %v", workers, m.num)
	}
}

type mockPool struct {
	download.Protocol
	num int
	mu  sync.Mutex
	ch  chan struct{}
}

func (m *mockPool) List(ctx context.Context, mod string) ([]string, error) {
	m.mu.Lock()
	m.num++
	if m.num == 5 {
		m.ch <- struct{}{}
	}
	m.mu.Unlock()

	time.Sleep(time.Minute)
	return nil, nil
}

// TestPoolWrapper ensures all upstream methods
// are successfully called.
func TestPoolWrapper(t *testing.T) {
	m := &mockDP{}
	dp := WithPool(1)(m)
	mod := "pkg"
	ver := "v0.1.0"
	m.inputMod = mod
	m.inputVer = ver
	m.list = []string{"v0.0.0", "v0.1.0"}
	m.catalog = []paths.AllPathParams{
		{Skill: "pkg", Version: "v0.1.0"},
	}
	givenList, err := dp.List(t.Context(), mod)
	if err != m.err {
		t.Fatalf("expected dp.List err to be %v but got %v", m.err, err)
	}
	if !reflect.DeepEqual(m.list, givenList) {
		t.Fatalf("dp.List: expected %v and %v to be equal", m.list, givenList)
	}
	m.info = []byte("info response")
	givenInfo, err := dp.Info(t.Context(), mod, ver)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(m.info, givenInfo) {
		t.Fatalf("dp.Info: expected %s and %s to be equal", m.info, givenInfo)
	}
	m.err = fmt.Errorf("zip err")
	_, err = dp.Zip(t.Context(), mod, ver)
	if m.err.Error() != err.Error() {
		t.Fatalf("dp.Zip: expected err to be `%v` but got `%v`", m.err, err)
	}
}

type mockDP struct {
	err      error
	list     []string
	info     []byte
	zip      storage.SizeReadCloser
	inputMod string
	inputVer string
	catalog  []paths.AllPathParams
}

// List implements GET /{skill}/@v/list
func (m *mockDP) List(ctx context.Context, mod string) ([]string, error) {
	if m.inputMod != mod {
		return nil, fmt.Errorf("expected mod input %v but got %v", m.inputMod, mod)
	}
	return m.list, m.err
}

// Info implements GET /{skill}/@v/{version}.info
func (m *mockDP) Info(ctx context.Context, mod, ver string) ([]byte, error) {
	if m.inputMod != mod {
		return nil, fmt.Errorf("expected mod input %v but got %v", m.inputMod, mod)
	}
	if m.inputVer != ver {
		return nil, fmt.Errorf("expected ver input %v but got %v", m.inputVer, ver)
	}
	return m.info, m.err
}

// Zip implements GET /{skill}/@v/{version}.zip
func (m *mockDP) Zip(ctx context.Context, mod, ver string) (storage.SizeReadCloser, error) {
	if m.inputMod != mod {
		return nil, fmt.Errorf("expected mod input %v but got %v", m.inputMod, mod)
	}
	if m.inputVer != ver {
		return nil, fmt.Errorf("expected ver input %v but got %v", m.inputVer, ver)
	}
	return m.zip, m.err
}

// Version is a helper method to get Info, Manifest, and Zip together.
func (m *mockDP) Version(ctx context.Context, mod, ver string) (*storage.Version, error) {
	panic("skipped")
}
