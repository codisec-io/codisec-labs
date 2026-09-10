package catalog

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFetchCatalog(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/catalog.json" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"schema_version": 1,
			"generated_at": "2026-01-01T00:00:00Z",
			"total": 1,
			"labs": [{"id":"devops-docker-fundamentos","title":"x","category":"devops","difficulty":"beginner","duration":"30m","description":"d","tags":[],"image":"docker:24-dind","image_published":true,"task_count":3,"maintainers":[]}]
		}`))
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, HTTPClient: srv.Client()}
	cat, err := c.FetchCatalog(context.Background())
	if err != nil {
		t.Fatalf("FetchCatalog: %v", err)
	}
	if cat.Total != 1 || len(cat.Labs) != 1 {
		t.Fatalf("catálogo inesperado: %+v", cat)
	}
	if cat.Labs[0].ID != "devops-docker-fundamentos" {
		t.Errorf("id inesperado: %s", cat.Labs[0].ID)
	}
	if !cat.Labs[0].ImagePublished {
		t.Errorf("esperava image_published=true")
	}
}

func TestFetchLabNotFound(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.NotFound(w, r)
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, HTTPClient: srv.Client()}
	_, err := c.FetchLab(context.Background(), "nao-existe")
	if err == nil {
		t.Fatal("esperava erro para lab inexistente, veio nil")
	}
}

func TestProductionBaseURLIsFixed(t *testing.T) {
	c := NewClient()
	if c.BaseURL != "https://codisec.com.br" {
		t.Fatalf("NewClient() não deveria apontar para outro lugar que não codisec.com.br, veio %q", c.BaseURL)
	}
}
