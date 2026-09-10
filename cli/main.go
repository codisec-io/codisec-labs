// Comando codisec — CLI que roda labs de AppSec/DevSecOps/DevOps
// localmente, no Docker do próprio usuário. Lê o catálogo público de
// codisec.com.br (sem autenticação, sem lógica de servidor por trás) e
// nunca fala com nenhum backend nosso além disso — ver
// docs/ARCHITECTURE.md.
package main

import "github.com/codisec/codisec-labs/cli/cmd"

func main() {
	cmd.Execute()
}
