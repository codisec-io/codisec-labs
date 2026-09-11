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
		"pula a confirmação interativa de labs que exigem modo privilegiado (uso não-interativo/scripts)")

	return cmd
}

// confirmPrivileged mostra o aviso de acesso privilegiado e lê uma
// resposta de in — só "y"/"yes" (sem diferenciar maiúscula/minúscula)
// conta como confirmação; qualquer outra coisa, incluindo Enter vazio
// ou EOF, é tratada como "não". O padrão é sempre negar, nunca subir um
// lab privilegiado sem confirmação explícita.
func confirmPrivileged(in io.Reader, out io.Writer) (bool, error) {
	fmt.Fprintln(out, "⚠️  Este lab exige acesso privilegiado ao Docker do host — equivalente")
	fmt.Fprintln(out, "    a acesso root nesta máquina. Só continue se confiar na origem")
	fmt.Fprintln(out, "    deste lab.")
	fmt.Fprintln(out)
	fmt.Fprint(out, "Continuar? [y/N] ")

	line, err := bufio.NewReader(in).ReadString('\n')
	if err != nil && err != io.EOF {
		return false, fmt.Errorf("lendo confirmação: %w", err)
	}
	answer := strings.ToLower(strings.TrimSpace(line))
	return answer == "y" || answer == "yes", nil
}
