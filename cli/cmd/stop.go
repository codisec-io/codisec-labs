package cmd

import (
	"github.com/spf13/cobra"

	"github.com/codisec-io/codisec-labs/cli/internal/dockerrun"
)

func newStopCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "stop <id>",
		Short: "Derruba e remove o container do lab",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			runner, err := dockerrun.NewRunner()
			if err != nil {
				return err
			}
			defer runner.Close()

			// Não precisa buscar o catálogo na rede — o nome do
			// container é derivado só do id, e stop precisa funcionar
			// mesmo se codisec.com.br estiver fora do ar.
			return runner.StopAndRemove(ctx, args[0])
		},
	}
}
