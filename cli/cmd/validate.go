package cmd

import (
	"errors"
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/codisec/codisec-labs/cli/internal/catalog"
	"github.com/codisec/codisec-labs/cli/internal/dockerrun"
	"github.com/codisec/codisec-labs/cli/internal/labspec"
)

func newValidateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "validate <id> <task-id>",
		Short: "Roda a validação de uma task e diz se ela passou",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			id, taskID := args[0], args[1]

			lab, err := catalog.NewClient().FetchLab(ctx, id)
			if err != nil {
				return err
			}
			task, ok := lab.FindTask(taskID)
			if !ok {
				return fmt.Errorf("task %q não existe no lab %q", taskID, id)
			}

			runner, err := dockerrun.NewRunner()
			if err != nil {
				return err
			}
			defer runner.Close()

			result, err := runner.RunCommand(ctx, lab.ID, task.Validation.Command)
			if err != nil {
				return err
			}

			if validationPassed(task.Validation, result) {
				fmt.Println("✓ " + task.Validation.SuccessMessage)
				return nil
			}
			fmt.Println("✗ " + task.Validation.ErrorMessage)
			return errors.New("validação falhou")
		},
	}
}

func validationPassed(v labspec.Validation, result dockerrun.ExecResult) bool {
	if v.ExpectedExitCode != nil {
		if result.ExitCode != *v.ExpectedExitCode {
			return false
		}
	} else if v.ExpectedOutputContains == "" {
		// Nem exit code nem saída esperada foram declarados no
		// lab.yaml — cai pro padrão mais comum: sucesso é sair com 0.
		if result.ExitCode != 0 {
			return false
		}
	}
	if v.ExpectedOutputContains != "" && !strings.Contains(result.Output, v.ExpectedOutputContains) {
		return false
	}
	return true
}
