package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/codisec-io/codisec-labs/cli/internal/catalog"
)

func newInfoCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "info <id>",
		Short: "Mostra a descrição e as tasks de um lab",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			lab, err := catalog.NewClient().FetchLab(ctx, args[0])
			if err != nil {
				return err
			}

			fmt.Printf("%s\n%s · %s · %s\n\n", lab.Title, lab.Category, lab.Difficulty, lab.Duration)
			fmt.Println(lab.Description)

			if !lab.ImagePublished {
				fmt.Printf("\n⚠️  A imagem Docker deste lab (%s) ainda não foi publicada pela equipe — `codisec lab start %s` vai falhar por enquanto.\n", lab.Image, lab.ID)
			}

			fmt.Println("\nTasks:")
			for i, t := range lab.Tasks {
				fmt.Printf("  %d. [%s] %s\n", i+1, t.ID, t.Title)
			}
			fmt.Printf("\nRodar: codisec lab start %s\n", lab.ID)
			return nil
		},
	}
}
