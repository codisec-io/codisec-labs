package cmd

import (
	"bytes"
	"strings"
	"testing"
)

func TestConfirmPrivileged(t *testing.T) {
	cases := []struct {
		input string
		want  bool
	}{
		{"y\n", true},
		{"Y\n", true},
		{"yes\n", true},
		{"YES\n", true},
		{"  y  \n", true},
		{"n\n", false},
		{"no\n", false},
		{"\n", false}, // só Enter — padrão é negar
		{"", false},   // EOF sem digitar nada — padrão é negar
		{"talvez\n", false},
	}

	for _, tc := range cases {
		t.Run(tc.input, func(t *testing.T) {
			var out bytes.Buffer
			got, err := confirmPrivileged(strings.NewReader(tc.input), &out)
			if err != nil {
				t.Fatalf("confirmPrivileged(%q): %v", tc.input, err)
			}
			if got != tc.want {
				t.Errorf("confirmPrivileged(%q) = %v, queria %v", tc.input, got, tc.want)
			}
			if !strings.Contains(out.String(), "Continuar?") {
				t.Error("aviso não foi impresso em out")
			}
			if !strings.Contains(out.String(), "acesso privilegiado") {
				t.Error("aviso não menciona acesso privilegiado")
			}
		})
	}
}
