// Package catalog busca o catálogo de labs e o detalhe de cada lab a
// partir do site estático da Codisec — nunca de uma URL arbitrária.
//
// Isso é uma decisão de segurança deliberada (ver docs/SECURITY.md): a
// CLI não expõe flag nem variável de ambiente pra trocar essa origem,
// justamente pra impedir que alguém induza um usuário a rodar
// `codisec lab start` apontando pra um catálogo malicioso hospedado em
// outro lugar. O campo BaseURL existe pra permitir teste automatizado
// (com httptest.Server) sem tocar em rede real — não é uma porta de
// configuração pensada pra uso externo.
package catalog

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/codisec/codisec-labs/cli/internal/labspec"
)

// ProductionBaseURL é a única origem que a CLI de fato usa em produção.
const ProductionBaseURL = "https://codisec.com.br"

type Client struct {
	BaseURL    string
	HTTPClient *http.Client
}

// NewClient cria o cliente de catálogo apontado pra produção. É o único
// construtor usado pelos comandos da CLI (cmd/*.go).
func NewClient() *Client {
	return &Client{
		BaseURL:    ProductionBaseURL,
		HTTPClient: &http.Client{Timeout: 15 * time.Second},
	}
}

func (c *Client) getJSON(ctx context.Context, path string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.BaseURL+path, nil)
	if err != nil {
		return fmt.Errorf("montando requisição para %s: %w", path, err)
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("buscando %s: %w", path, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("%s respondeu %d: %s", path, resp.StatusCode, string(body))
	}

	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("decodificando %s: %w", path, err)
	}
	return nil
}

// FetchCatalog busca o índice completo de labs (/catalog.json).
func (c *Client) FetchCatalog(ctx context.Context) (*labspec.Catalog, error) {
	var cat labspec.Catalog
	if err := c.getJSON(ctx, "/catalog.json", &cat); err != nil {
		return nil, err
	}
	return &cat, nil
}

// FetchLab busca o detalhe completo de um lab (/labs/<id>.json).
func (c *Client) FetchLab(ctx context.Context, id string) (*labspec.Lab, error) {
	var lab labspec.Lab
	if err := c.getJSON(ctx, "/labs/"+id+".json", &lab); err != nil {
		return nil, fmt.Errorf("lab %q: %w", id, err)
	}
	return &lab, nil
}
