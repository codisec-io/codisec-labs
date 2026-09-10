package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/codisec/codisec-labs/cli/internal/catalog"
	"github.com/codisec/codisec-labs/cli/internal/dockerrun"
)

func newStartCmd() *cobra.Command {
	return &cobra.Command{
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
}
