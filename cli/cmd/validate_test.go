package cmd

import (
	"testing"

	"github.com/codisec/codisec-labs/cli/internal/dockerrun"
	"github.com/codisec/codisec-labs/cli/internal/labspec"
)

func intPtr(i int) *int { return &i }

// Espelha os três padrões reais usados em labs/*/lab.yaml (ver
// appsec-idor-api): só exit code, só output, e o caso sem nenhum dos
// dois declarado.
func TestValidationPassed(t *testing.T) {
	cases := []struct {
		name   string
		v      labspec.Validation
		result dockerrun.ExecResult
		want   bool
	}{
		{
			name:   "exit code esperado bate (grep -q)",
			v:      labspec.Validation{ExpectedExitCode: intPtr(0)},
			result: dockerrun.ExecResult{ExitCode: 0},
			want:   true,
		},
		{
			name:   "exit code esperado não bate",
			v:      labspec.Validation{ExpectedExitCode: intPtr(0)},
			result: dockerrun.ExecResult{ExitCode: 1},
			want:   false,
		},
		{
			name:   "só output esperado, sem checar exit code (curl -w %{http_code})",
			v:      labspec.Validation{ExpectedOutputContains: "403"},
			result: dockerrun.ExecResult{ExitCode: 0, Output: "403"},
			want:   true,
		},
		{
			name:   "output esperado ausente na saída",
			v:      labspec.Validation{ExpectedOutputContains: "403"},
			result: dockerrun.ExecResult{ExitCode: 0, Output: "200"},
			want:   false,
		},
		{
			name:   "nem exit code nem output declarados — padrão é exit 0",
			v:      labspec.Validation{},
			result: dockerrun.ExecResult{ExitCode: 0},
			want:   true,
		},
		{
			name:   "nem exit code nem output declarados, comando falhou",
			v:      labspec.Validation{},
			result: dockerrun.ExecResult{ExitCode: 1},
			want:   false,
		},
		{
			name:   "exit code E output declarados, os dois batem",
			v:      labspec.Validation{ExpectedExitCode: intPtr(0), ExpectedOutputContains: "ok"},
			result: dockerrun.ExecResult{ExitCode: 0, Output: "ok"},
			want:   true,
		},
		{
			name:   "exit code bate mas output não",
			v:      labspec.Validation{ExpectedExitCode: intPtr(0), ExpectedOutputContains: "ok"},
			result: dockerrun.ExecResult{ExitCode: 0, Output: "nope"},
			want:   false,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := validationPassed(tc.v, tc.result)
			if got != tc.want {
				t.Errorf("validationPassed(%+v, %+v) = %v, queria %v", tc.v, tc.result, got, tc.want)
			}
		})
	}
}
