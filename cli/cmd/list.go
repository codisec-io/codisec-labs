package cmd

import (
	"fmt"
	"os"
	"text/tabwriter"

	"github.com/spf13/cobra"

	"github.com/codisec-io/codisec-labs/cli/internal/catalog"
)

func newListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "Lista todos os labs do catálogo",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			cat, err := catalog.NewClient().FetchCatalog(ctx)
			if err != nil {
				return fmt.Errorf("buscando catálogo: %w", err)
			}

			w := tabwriter.NewWriter(os.Stdout, 0, 2, 2, ' ', 0)
			fmt.Fprintln(w, "ID\tCATEGORIA\tDIFICULDADE\tDURAÇÃO\tIMAGEM PUBLICADA")
			for _, lab := range cat.Labs {
				published := "não"
				if lab.ImagePublished {
					published = "sim"
				}
				fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", lab.ID, lab.Category, lab.Difficulty, lab.Duration, published)
			}
			if err := w.Flush(); err != nil {
				return err
			}
			fmt.Printf("\n%d lab(s). Detalhes: codisec lab info <id>\n", cat.Total)
			return nil
		},
	}
}
