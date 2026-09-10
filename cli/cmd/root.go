// Package cmd implementa a árvore de comandos da CLI (codisec lab ...).
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// version é preenchida em build time via -ldflags (ver cli/.goreleaser.yml).
var version = "dev"

// Execute roda a CLI a partir de main.go.
func Execute() {
	if err := newRootCmd().Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "erro:", err)
		os.Exit(1)
	}
}

func newRootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:           "codisec",
		Short:         "CLI da Codisec — roda labs de AppSec/DevSecOps/DevOps localmente",
		Version:       version,
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	labCmd := &cobra.Command{
		Use:   "lab",
		Short: "Comandos para listar, iniciar, validar e derrubar labs",
	}
	labCmd.AddCommand(
		newListCmd(),
		newInfoCmd(),
		newStartCmd(),
		newValidateCmd(),
		newStopCmd(),
		newResetCmd(),
	)

	root.AddCommand(labCmd)
	return root
}
