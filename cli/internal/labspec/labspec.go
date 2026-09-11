// Package labspec define as estruturas Go que espelham o formato gerado
// por scripts/build_catalog.py (catalog.json e labs/<id>.json), que por
// sua vez espelha labs/schema.json. Se um desses três mudar, os outros
// dois precisam mudar junto.
package labspec

// CatalogEntry é uma entrada do índice em /catalog.json — leve, sem as
// tasks completas (essas só existem no /labs/<id>.json de cada lab).
type CatalogEntry struct {
	ID                   string   `json:"id"`
	Title                string   `json:"title"`
	Category             string   `json:"category"`
	Difficulty           string   `json:"difficulty"`
	Duration             string   `json:"duration"`
	Description          string   `json:"description"`
	Tags                 []string `json:"tags"`
	Image                string   `json:"image"`
	ImagePublished       bool     `json:"image_published"`
	RequiresPrivileged   bool     `json:"requires_privileged"`
	RequiredCapabilities []string `json:"required_capabilities"`
	TaskCount            int      `json:"task_count"`
	Maintainers          []string `json:"maintainers"`
}

// Catalog é o conteúdo de /catalog.json.
type Catalog struct {
	SchemaVersion int            `json:"schema_version"`
	GeneratedAt   string         `json:"generated_at"`
	Total         int            `json:"total"`
	Labs          []CatalogEntry `json:"labs"`
}

// Validation é o bloco validation de uma task.
type Validation struct {
	Command                string `json:"command"`
	ExpectedExitCode       *int   `json:"expected_exit_code,omitempty"`
	ExpectedOutputContains string `json:"expected_output_contains,omitempty"`
	SuccessMessage         string `json:"success_message"`
	ErrorMessage           string `json:"error_message"`
}

// Task é uma tarefa dentro de um lab (theory → steps → validation).
type Task struct {
	ID                string     `json:"id"`
	Title             string     `json:"title"`
	Theory            string     `json:"theory"`
	Steps             []string   `json:"steps"`
	BreakAgainCommand string     `json:"break_again_command,omitempty"`
	Validation        Validation `json:"validation"`
}

// Recovery é o bloco recovery de um lab.
type Recovery struct {
	ResetCommand string `json:"reset_command"`
}

// Lab é o conteúdo completo de /labs/<id>.json — equivalente ao
// lab.yaml original, mas em JSON, sem precisar de parser YAML na CLI.
type Lab struct {
	ID                   string   `json:"id"`
	Title                string   `json:"title"`
	Category             string   `json:"category"`
	Difficulty           string   `json:"difficulty"`
	Duration             string   `json:"duration"`
	Description          string   `json:"description"`
	Image                string   `json:"image"`
	ImagePublished       bool     `json:"image_published"`
	RequiresPrivileged   bool     `json:"requires_privileged"`
	RequiredCapabilities []string `json:"required_capabilities"`
	Tags                 []string `json:"tags"`
	Maintainers          []string `json:"maintainers"`
	ExposedPorts         []int    `json:"exposed_ports"`
	Tasks                []Task   `json:"tasks"`
	Recovery             Recovery `json:"recovery"`
}

// FindTask procura uma task pelo id dentro do lab.
func (l Lab) FindTask(taskID string) (Task, bool) {
	for _, t := range l.Tasks {
		if t.ID == taskID {
			return t, true
		}
	}
	return Task{}, false
}

// ContainerName é o nome fixo do container Docker de um lab — permite
// localizar o container em start/validate/stop/reset sem guardar estado
// próprio em disco. Função de pacote (não método) porque comandos como
// `codisec lab stop <id>` operam só com o id, sem precisar buscar o
// lab completo na rede.
func ContainerName(labID string) string {
	return "codisec-lab-" + labID
}
