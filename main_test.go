package main

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func serviceForTest(t *testing.T) *Service {
	t.Helper()
	base := t.TempDir()
	library := filepath.Join(base, "library")
	os.Mkdir(library, 0700)
	return &Service{library: library, staging: filepath.Join(base, "staging"), configPath: filepath.Join(base, "config.json"), engineURL: "http://127.0.0.1:38768", engineToken: strings.Repeat("a", 32), client: &http.Client{}}
}
func TestSettingsAreLogicalAndDoNotExposeToken(t *testing.T) {
	s := serviceForTest(t)
	id := "12345678-1234-1234-1234-123456789abc"
	saveJSON(filepath.Join(s.library, id+".metadata"), map[string]string{"type": "CollectionType", "visibleName": "Books", "parent": ""})
	request := func(method, body, origin, header string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, "/settings", strings.NewReader(body))
		r.Header.Set("X-ArchiveBooks-Request", header)
		r.Header.Set("Origin", origin)
		w := httptest.NewRecorder()
		s.handler().ServeHTTP(w, r)
		return w
	}
	for _, v := range []struct{ origin, header string }{{"", ""}, {"https://example.org", "app"}} {
		if w := request("GET", "", v.origin, v.header); w.Code != 403 {
			t.Fatal(w.Code)
		}
	}
	w := request("POST", `{"folder":"`+id+`"}`, "", "app")
	if w.Code != 200 {
		t.Fatal(w.Body.String())
	}
	if strings.Contains(w.Body.String(), s.engineToken) || strings.Contains(w.Body.String(), s.library) {
		t.Fatal("exposed private configuration")
	}
	if s.config.Folder != id {
		t.Fatal("folder not saved")
	}
	if w = request("POST", `{"folder":"../../etc"}`, "", "app"); w.Code != 400 {
		t.Fatal(w.Code)
	}
	if s.config.Folder != id {
		t.Fatal("invalid folder replaced saved selection")
	}
}
func TestStageValidatesActualBookAndPreservesTitle(t *testing.T) {
	s := serviceForTest(t)
	payload := "<html>CAPTCHA</html>"
	s.client.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.Header.Get("Authorization") != "Bearer "+s.engineToken {
			t.Fatal("missing local engine authorization")
		}
		return &http.Response{StatusCode: 200, Header: http.Header{"X-Book-Format": []string{"pdf"}}, Body: io.NopCloser(strings.NewReader(payload))}, nil
	})
	if _, err := s.stage(context.Background(), "Example"); err == nil {
		t.Fatal("imported CAPTCHA as PDF")
	}
	payload = "%PDF-1.7\nexample PDF fixture"
	if _, err := s.stage(context.Background(), "../Against Intellectual Monopoly"); err != nil {
		t.Fatal(err)
	}
	if !strings.HasSuffix(s.staged, "Against Intellectual Monopoly.pdf") {
		t.Fatal(s.staged)
	}
	if !strings.HasPrefix(s.staged, s.staging+string(os.PathSeparator)) {
		t.Fatal("escaped staging")
	}
	if _, err := os.Stat(s.staged); err != nil {
		t.Fatal(err)
	}
	staged := s.staged
	if _, err := s.stage(context.Background(), "Other title"); err != nil || s.staged != staged {
		t.Fatal("retry duplicated staging", err)
	}
}
func TestDeletedDestinationStopsDownload(t *testing.T) {
	s := serviceForTest(t)
	s.config.Folder = "12345678-1234-1234-1234-123456789abc"
	s.client.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		t.Fatal("fetched before validating destination")
		return nil, nil
	})
	if _, err := s.stage(context.Background(), "Book"); err == nil {
		t.Fatal("accepted deleted destination")
	}
}
