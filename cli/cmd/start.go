package cmd

import (
	"bufio"
	"fmt"
	"io"
	"strings"

	"github.com/spf13/cobra"

	"github.com/codisec-io/codisec-labs/cli/internal/catalog"
	"github.com/codisec-io/codisec-labs/cli/internal/dockerrun"
)

func newStartCmd() *cobra.Command {
	var assumeYes bool

	cmd := &cobra.Command{
		Use:   "start <id>",
		Short: "Sobe o lab localmente e abre um terminal conectado a ele",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			id := args[0]

			lab, err := catalog.NewClient().FetchLab(ctx, id)
			if err != nil {
				return err
			}
			if !lab.ImagePublished {
				fmt.Printf(
					"⚠️  A imagem Docker deste lab (%s) ainda não foi publicada pela equipe — não é possível iniciar agora.\n",
					lab.Image,
				)
				return nil
			}

			// requires_privileged e required_capabilities não são cumulativos
			// pra fins de aviso: privilégio total já cobre qualquer
			// capability específica, então só um dos dois avisos é mostrado.
			if lab.RequiresPrivileged {
				if assumeYes {
					fmt.Fprintln(cmd.OutOrStdout(), "⚠️  Lab privilegiado — confirmação pulada por --yes.")
				} else {
					confirmed, err := confirmPrivileged(cmd.InOrStdin(), cmd.OutOrStdout())
					if err != nil {
						return err
					}
					if !confirmed {
						fmt.Fprintln(cmd.OutOrStdout(), "Cancelado — nenhum container foi criado.")
						return nil
					}
				}
			} else if len(lab.RequiredCapabilities) > 0 {
				if assumeYes {
					fmt.Fprintln(cmd.OutOrStdout(), "ℹ️  Lab com capabilities extras — confirmação pulada por --yes.")
				} else {
					confirmed, err := confirmCapabilities(lab.RequiredCapabilities, cmd.InOrStdin(), cmd.OutOrStdout())
					if err != nil {
						return err
					}
					if !confirmed {
						fmt.Fprintln(cmd.OutOrStdout(), "Cancelado — nenhum container foi criado.")
						return nil
					}
				}
			}

			runner, err := dockerrun.NewRunner()
			if err != nil {
				return err
			}
			defer runner.Close()

			if err := runner.StartContainer(ctx, *lab); err != nil {
				return err
			}

			fmt.Println("Conectando terminal... (Ctrl+D ou `exit` para sair — o container continua rodando)")
			return runner.AttachInteractiveShell(ctx, lab.ID)
		},
	}

	cmd.Flags().BoolVarP(&assumeYes, "yes", "y", false,
		"pula a confirmação interativa de labs que exigem modo privilegiado ou capabilities extras (uso não-interativo/scripts)")

	return cmd
}

// confirmPrivileged mostra o aviso de acesso privilegiado e pede
// confirmação explícita antes de subir um lab com requires_privileged:
// true — nunca em silêncio.
func confirmPrivileged(in io.Reader, out io.Writer) (bool, error) {
	fmt.Fprintln(out, "⚠️  Este lab exige acesso privilegiado ao Docker do host — equivalente")
	fmt.Fprintln(out, "    a acesso root nesta máquina. Só continue se confiar na origem")
	fmt.Fprintln(out, "    deste lab.")
	fmt.Fprintln(out)
	return readYesNo(in, out)
}

// confirmCapabilities mostra o aviso de capabilities específicas
// (required_capabilities) e pede confirmação. Deliberadamente mais
// brando que confirmPrivileged — não é acesso root, é uma permissão
// pontual (ex: NET_ADMIN pra manipular interfaces de rede).
func confirmCapabilities(caps []string, in io.Reader, out io.Writer) (bool, error) {
	fmt.Fprintf(out, "ℹ️  Este lab pede a(s) permissão(ões) de rede: %s.\n", strings.Join(caps, ", "))
	fmt.Fprintln(out, "    Isso é mais restrito que acesso root, mas ainda maior que o")
	fmt.Fprintln(out, "    padrão de um container comum.")
	fmt.Fprintln(out)
	return readYesNo(in, out)
}

// readYesNo lê uma resposta de in — só "y"/"yes" (sem diferenciar
// maiúscula/minúscula) conta como confirmação; qualquer outra coisa,
// incluindo Enter vazio ou EOF, é tratada como "não". O padrão é sempre
// negar, nunca subir um lab privilegiado (ou com capabilities extras)
// sem confirmação explícita.
func readYesNo(in io.Reader, out io.Writer) (bool, error) {
	fmt.Fprint(out, "Continuar? [y/N] ")

	line, err := bufio.NewReader(in).ReadString('\n')
	if err != nil && err != io.EOF {
		return false, fmt.Errorf("lendo confirmação: %w", err)
	}
	answer := strings.ToLower(strings.TrimSpace(line))
	return answer == "y" || answer == "yes", nil
}
