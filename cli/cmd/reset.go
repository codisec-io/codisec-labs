package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/codisec/codisec-labs/cli/internal/catalog"
	"github.com/codisec/codisec-labs/cli/internal/dockerrun"
)

func newResetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "reset <id>",
		Short: "Restaura o lab pro estado inicial (recovery.reset_command)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			id := args[0]

			lab, err := catalog.NewClient().FetchLab(ctx, id)
			if err != nil {
				return err
			}

			runner, err := dockerrun.NewRunner()
			if err != nil {
				return err
			}
			defer runner.Close()

			result, err := runner.RunCommand(ctx, lab.ID, lab.Recovery.ResetCommand)
			if err != nil {
				return err
			}
			if result.ExitCode != 0 {
				return fmt.Errorf("reset terminou com código %d:\n%s", result.ExitCode, result.Output)
			}

			fmt.Println("✓ Lab restaurado para o estado inicial.")
			return nil
		},
	}
}
