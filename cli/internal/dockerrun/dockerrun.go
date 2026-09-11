// Package dockerrun fala com o Docker do próprio usuário (via socket
// local, o mesmo que o comando `docker` usa) pra subir, conectar,
// validar e derrubar containers de lab. Nunca fala com nenhum servidor
// nosso — é exatamente o ponto do modelo de execução local (ver
// docs/ARCHITECTURE.md).
package dockerrun

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/api/types/image"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/client"
	"github.com/docker/docker/pkg/stdcopy"
	"github.com/docker/go-connections/nat"
	"golang.org/x/term"

	"github.com/codisec-io/codisec-labs/cli/internal/labspec"
)

// LabLabelKey marca todo container criado pela CLI com o id do lab —
// permite localizar/filtrar sem guardar estado próprio em disco.
const LabLabelKey = "com.codisec.lab"

type Runner struct {
	cli *client.Client
}

func NewRunner() (*Runner, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, fmt.Errorf("conectando ao Docker local: %w (o Docker Desktop está aberto?)", err)
	}
	return &Runner{cli: cli}, nil
}

func (r *Runner) Close() error {
	return r.cli.Close()
}

// EnsureImage baixa a imagem se ela ainda não existir localmente,
// mostrando progresso simples (sem barra bonita — é só pra não deixar o
// usuário sem feedback num pull que pode demorar).
func (r *Runner) EnsureImage(ctx context.Context, ref string) error {
	_, _, err := r.cli.ImageInspectWithRaw(ctx, ref)
	if err == nil {
		return nil // já tem local
	}

	fmt.Fprintf(os.Stderr, "Baixando %s...\n", ref)
	reader, err := r.cli.ImagePull(ctx, ref, image.PullOptions{})
	if err != nil {
		return fmt.Errorf("baixando imagem %s: %w", ref, err)
	}
	defer reader.Close()

	// Drena o stream de progresso (formato JSON linha-a-linha do
	// Docker) sem tentar renderizar uma barra de progresso — só
	// confirma que o pull está avançando e captura o erro final, se
	// houver.
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		// intencionalmente silencioso linha a linha; erros reais do
		// pull chegam via err do ImagePull ou ficam no corpo e são
		// reportados pelo Docker daemon como falha subsequente (ex:
		// container create falha se a imagem não existir).
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("lendo progresso do pull de %s: %w", ref, err)
	}

	fmt.Fprintf(os.Stderr, "✓ Imagem baixada.\n")
	return nil
}

// portBindings converte a lista exposed_ports do lab.yaml em bindings
// idênticos no host (mesma porta dentro e fora) — os steps de cada lab
// fazem `curl localhost:<porta>` literal, então não remapeamos.
func portBindings(ports []int) (nat.PortSet, nat.PortMap) {
	exposed := nat.PortSet{}
	bindings := nat.PortMap{}
	for _, p := range ports {
		port := nat.Port(fmt.Sprintf("%d/tcp", p))
		exposed[port] = struct{}{}
		bindings[port] = []nat.PortBinding{{HostIP: "127.0.0.1", HostPort: fmt.Sprintf("%d", p)}}
	}
	return exposed, bindings
}

// StartContainer sobe (ou reaproveita, se já estiver rodando) o
// container do lab, usando o CMD/ENTRYPOINT padrão da imagem.
func (r *Runner) StartContainer(ctx context.Context, lab labspec.Lab) error {
	return r.startWithCommand(ctx, lab, nil)
}

// startWithCommand é a implementação real de StartContainer, com um
// override opcional de Cmd — usado pelos testes de integração pra subir
// uma imagem genérica (alpine) que não tem um processo de longa duração
// por padrão, sem duplicar a lógica de criação de container.
func (r *Runner) startWithCommand(ctx context.Context, lab labspec.Lab, cmdOverride []string) error {
	name := labspec.ContainerName(lab.ID)

	existing, err := r.findContainer(ctx, name)
	if err != nil {
		return err
	}
	if existing != "" {
		insp, err := r.cli.ContainerInspect(ctx, existing)
		if err == nil && insp.State != nil && insp.State.Running {
			fmt.Fprintf(os.Stderr, "Container %s já está rodando.\n", name)
			return nil
		}
		// existe mas está parado — remove e recria do zero, mais
		// previsível do que tentar reiniciar um estado desconhecido.
		_ = r.cli.ContainerRemove(ctx, existing, container.RemoveOptions{Force: true})
	}

	if err := r.EnsureImage(ctx, lab.Image); err != nil {
		return err
	}

	exposedPorts, bindings := portBindings(lab.ExposedPorts)

	if lab.RequiresPrivileged {
		fmt.Fprintf(os.Stderr, "Subindo em modo privilegiado (requires_privileged: true no lab.yaml)...\n")
	}

	resp, err := r.cli.ContainerCreate(ctx,
		&container.Config{
			Image:        lab.Image,
			Cmd:          cmdOverride,
			Labels:       map[string]string{LabLabelKey: lab.ID},
			Tty:          false,
			ExposedPorts: exposedPorts,
		},
		&container.HostConfig{
			PortBindings: bindings,
			AutoRemove:   false,
			// Só true quando o lab.yaml declara requires_privileged —
			// nunca por padrão. Ver docs/SECURITY.md, "Labs que exigem
			// modo privilegiado": a confirmação interativa acontece
			// antes disso, em cmd/start.go, nunca aqui em silêncio.
			Privileged: lab.RequiresPrivileged,
		},
		&network.NetworkingConfig{},
		nil,
		name,
	)
	if err != nil {
		return fmt.Errorf("criando container %s: %w", name, err)
	}

	if err := r.cli.ContainerStart(ctx, resp.ID, container.StartOptions{}); err != nil {
		return fmt.Errorf("iniciando container %s: %w", name, err)
	}

	fmt.Fprintf(os.Stderr, "✓ Lab pronto. Container %s rodando.\n", name)
	return nil
}

func (r *Runner) findContainer(ctx context.Context, name string) (string, error) {
	containers, err := r.cli.ContainerList(ctx, container.ListOptions{
		All:     true,
		Filters: filters.NewArgs(filters.Arg("name", "^/"+name+"$")),
	})
	if err != nil {
		return "", fmt.Errorf("procurando container %s: %w", name, err)
	}
	if len(containers) == 0 {
		return "", nil
	}
	return containers[0].ID, nil
}

// shellCommand escolhe bash se existir, senão cai pra sh — a maioria
// das imagens de lab não garante bash instalado.
var shellCommand = []string{"sh", "-c", "if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi"}

// AttachInteractiveShell abre um terminal local de verdade dentro do
// container (docker exec -it, sem WebSocket, sem porta exposta) —
// equivalente ao `docker exec -it <container> sh`. Só precisa do id do
// lab (não faz nenhuma chamada de rede).
func (r *Runner) AttachInteractiveShell(ctx context.Context, labID string) error {
	name := labspec.ContainerName(labID)
	containerID, err := r.findContainer(ctx, name)
	if err != nil {
		return err
	}
	if containerID == "" {
		return fmt.Errorf("container %s não encontrado — rode `codisec lab start %s` primeiro", name, labID)
	}

	execID, err := r.cli.ContainerExecCreate(ctx, containerID, container.ExecOptions{
		Cmd:          shellCommand,
		AttachStdin:  true,
		AttachStdout: true,
		AttachStderr: true,
		Tty:          true,
	})
	if err != nil {
		return fmt.Errorf("criando sessão de terminal: %w", err)
	}

	resp, err := r.cli.ContainerExecAttach(ctx, execID.ID, container.ExecAttachOptions{Tty: true})
	if err != nil {
		return fmt.Errorf("conectando terminal: %w", err)
	}
	defer resp.Close()

	stdinFd := int(os.Stdin.Fd())
	if term.IsTerminal(stdinFd) {
		oldState, err := term.MakeRaw(stdinFd)
		if err == nil {
			defer term.Restore(stdinFd, oldState)
		}
	}

	errCh := make(chan error, 1)
	go func() {
		_, err := io.Copy(os.Stdout, resp.Reader)
		errCh <- err
	}()
	go func() {
		_, _ = io.Copy(resp.Conn, os.Stdin)
		// Repassa o EOF do nosso stdin pro lado do container (metade
		// da conexão fechada pra escrita) — sem isso, um shell que
		// receba EOF num stdin não-interativo (script, CI, `< arquivo`)
		// nunca é avisado disso e fica esperando entrada pra sempre.
		// Num terminal real interativo isso não muda nada: o usuário
		// sai com `exit`/Ctrl+D, que já passa por aqui do mesmo jeito.
		if cw, ok := resp.Conn.(interface{ CloseWrite() error }); ok {
			_ = cw.CloseWrite()
		}
	}()

	select {
	case err := <-errCh:
		if err != nil && err != io.EOF {
			return fmt.Errorf("sessão de terminal encerrada com erro: %w", err)
		}
	case <-ctx.Done():
		return ctx.Err()
	}
	return nil
}

// ExecResult é o resultado de um comando não-interativo (validate/reset).
type ExecResult struct {
	ExitCode int
	Output   string
}

// RunCommand roda um comando dentro do container (validation.command ou
// recovery.reset_command), sem TTY, capturando saída combinada e o
// exit code.
func (r *Runner) RunCommand(ctx context.Context, labID string, command string) (ExecResult, error) {
	name := labspec.ContainerName(labID)
	containerID, err := r.findContainer(ctx, name)
	if err != nil {
		return ExecResult{}, err
	}
	if containerID == "" {
		return ExecResult{}, fmt.Errorf("container %s não encontrado — rode `codisec lab start %s` primeiro", name, labID)
	}

	execID, err := r.cli.ContainerExecCreate(ctx, containerID, container.ExecOptions{
		Cmd:          []string{"sh", "-c", command},
		AttachStdout: true,
		AttachStderr: true,
		Tty:          false,
	})
	if err != nil {
		return ExecResult{}, fmt.Errorf("criando execução: %w", err)
	}

	resp, err := r.cli.ContainerExecAttach(ctx, execID.ID, container.ExecAttachOptions{})
	if err != nil {
		return ExecResult{}, fmt.Errorf("executando comando: %w", err)
	}
	defer resp.Close()

	var stdout, stderr strings.Builder
	if _, err := stdcopy.StdCopy(&stdout, &stderr, resp.Reader); err != nil {
		return ExecResult{}, fmt.Errorf("lendo saída do comando: %w", err)
	}

	// Espera o exec realmente terminar antes de checar o exit code —
	// ContainerExecAttach retorna assim que os streams fecham, o que
	// já é suficiente aqui, mas fazemos um poll curto por segurança em
	// daemons mais lentos a reportar o ExitCode.
	var inspect container.ExecInspect
	for i := 0; i < 20; i++ {
		inspect, err = r.cli.ContainerExecInspect(ctx, execID.ID)
		if err != nil {
			return ExecResult{}, fmt.Errorf("inspecionando execução: %w", err)
		}
		if !inspect.Running {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}

	return ExecResult{
		ExitCode: inspect.ExitCode,
		Output:   stdout.String() + stderr.String(),
	}, nil
}

// StopAndRemove derruba e remove o container do lab. Só precisa do id
// do lab — não faz nenhuma chamada de rede, funciona mesmo se
// codisec.com.br estiver fora do ar.
func (r *Runner) StopAndRemove(ctx context.Context, labID string) error {
	name := labspec.ContainerName(labID)
	containerID, err := r.findContainer(ctx, name)
	if err != nil {
		return err
	}
	if containerID == "" {
		fmt.Fprintf(os.Stderr, "Container %s não estava rodando.\n", name)
		return nil
	}

	timeout := 10
	if err := r.cli.ContainerStop(ctx, containerID, container.StopOptions{Timeout: &timeout}); err != nil {
		return fmt.Errorf("parando container %s: %w", name, err)
	}
	if err := r.cli.ContainerRemove(ctx, containerID, container.RemoveOptions{Force: true}); err != nil {
		return fmt.Errorf("removendo container %s: %w", name, err)
	}

	fmt.Fprintf(os.Stderr, "✓ Container %s removido.\n", name)
	return nil
}
