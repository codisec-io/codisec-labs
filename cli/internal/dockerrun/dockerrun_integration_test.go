// Testes de integração de verdade contra o Docker local. Pulados
// automaticamente se não houver Docker disponível (ex: CI sem
// privilégio de rodar containers) — não usam mock nenhum, é o mesmo
// caminho que a CLI real percorre.
package dockerrun

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/codisec/codisec-labs/cli/internal/labspec"
)

func newTestRunner(t *testing.T) *Runner {
	t.Helper()
	r, err := NewRunner()
	if err != nil {
		t.Skipf("Docker não disponível, pulando teste de integração: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if _, err := r.findContainer(ctx, "codisec-lab-__ping__"); err != nil {
		t.Skipf("Docker não respondeu, pulando teste de integração: %v", err)
	}
	return r
}

// TestLifecycle sobe um container real (alpine, sempre público e leve),
// roda uma "validação" que passa e outra que falha, e derruba tudo —
// o mesmo ciclo start → validate → stop que `codisec lab` expõe.
func TestLifecycle(t *testing.T) {
	if testing.Short() {
		t.Skip("pulando teste de integração em -short")
	}

	r := newTestRunner(t)
	defer r.Close()

	lab := labspec.Lab{
		ID:    "e2e-alpine-smoke",
		Image: "alpine:latest",
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// Alpine sozinho sai na hora (sem processo de longa duração) —
	// dá um `sleep` pra manter o container de pé pro exec funcionar,
	// do mesmo jeito que uma imagem de lab real ficaria de pé rodando
	// seu serviço.
	t.Cleanup(func() {
		cleanupCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		_ = r.StopAndRemove(cleanupCtx, lab.ID)
	})

	if err := r.startWithCommand(ctx, lab, []string{"sleep", "300"}); err != nil {
		t.Fatalf("StartContainer: %v", err)
	}

	// Uma validação que deve passar.
	result, err := r.RunCommand(ctx, lab.ID, "echo hello-codisec")
	if err != nil {
		t.Fatalf("RunCommand (deveria passar): %v", err)
	}
	if result.ExitCode != 0 {
		t.Errorf("exit code = %d, queria 0", result.ExitCode)
	}
	if !strings.Contains(result.Output, "hello-codisec") {
		t.Errorf("output = %q, queria conter hello-codisec", result.Output)
	}

	// Uma validação que deve falhar (exit code != 0).
	result, err = r.RunCommand(ctx, lab.ID, "exit 7")
	if err != nil {
		t.Fatalf("RunCommand (deveria rodar mas falhar): %v", err)
	}
	if result.ExitCode != 7 {
		t.Errorf("exit code = %d, queria 7", result.ExitCode)
	}

	if err := r.StopAndRemove(ctx, lab.ID); err != nil {
		t.Fatalf("StopAndRemove: %v", err)
	}

	// Depois de removido, mandar rodar comando de novo deve dar erro
	// claro (container não encontrado), não travar.
	if _, err := r.RunCommand(ctx, lab.ID, "echo x"); err == nil {
		t.Error("esperava erro ao rodar comando em container já removido")
	}
}
