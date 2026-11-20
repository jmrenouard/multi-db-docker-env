// Package interactive provides the native bilingual wizard and HTML run report for mdb.
package interactive

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/dbclient"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

// StepExecutor runs an mdb CLI subcommand and returns stdout, stderr, and error.
type StepExecutor func(ctx context.Context, args []string) (string, string, error)

// VerifierRunner verifies connectivity and cluster health for an environment.
type VerifierRunner func(ctx context.Context, env catalog.Environment) (string, error)

// Step represents a single wizard execution step.
type Step struct {
	ID, Name, Description, Command string
	Args                           []string
	Run                            func(ctx context.Context) (string, string, error)
}

// StepResult captures the outcome of a wizard step for HTML reporting.
type StepResult struct {
	Step
	Status string
	Stdout string
	Stderr string
}

// Options configures a wizard run.
type Options struct {
	Auto, Interactive bool
	Lang, ReportPath  string
	Catalog           *catalog.Catalog
	In                io.Reader
	Out               io.Writer
	Exec              StepExecutor
	Verify            VerifierRunner
	DockerClient      *docker.Client
}

type uiStrings struct {
	LangPrompt, SelectCat, CatStandalone, CatCluster, SelectEnv, Choice, InvalidChoice string
	ModePrompt, AutoLabel, InterLabel, RunStep, RetryPrompt, Failed, Executing         string
	Dashboard, Logs, Stdout, Stderr, NoOut, NoErr, FinalReport                         string
}

var i18n = map[string]uiStrings{
	"en": {
		LangPrompt:    "Select Language / Sélectionnez la langue ([e]n / [f]r - default: e): ",
		SelectCat:     "\nSelect Environment Category (or enter an environment ID directly):",
		CatStandalone: "1. Standalone (%d active profiles)",
		CatCluster:    "2. Cluster / High Availability (%d topologies)",
		SelectEnv:     "\nSelect %s Environment:",
		Choice:        "Choice",
		InvalidChoice: "Invalid choice; falling back to default.",
		ModePrompt:    "Run mode ([a]uto / [i]nteractive - default: i)? ",
		AutoLabel:     "Mode: Automated",
		InterLabel:    "Mode: Interactive",
		RunStep:       "   Run this step? (Y/n) ",
		RetryPrompt:   "   Step failed. [r]etry / [c]ontinue / [s]top (default: r): ",
		Failed:        "Step failed: %v",
		Executing:     "\nExecuting: %s",
		Dashboard:     "mdb Interactive Dashboard",
		Logs:          "Logs",
		Stdout:        "Standard Output",
		Stderr:        "Standard Error",
		NoOut:         "(no output)",
		NoErr:         "(no error output)",
		FinalReport:   "\nCompleted. Final report: %s\n",
	},
	"fr": {
		LangPrompt:    "Select Language / Sélectionnez la langue ([e]n / [f]r - default: e) : ",
		SelectCat:     "\nSélectionnez le type d'environnement (ou saisissez directement un ID) :",
		CatStandalone: "1. Autonome (%d profils actifs)",
		CatCluster:    "2. Cluster / Haute Disponibilité (%d topologies)",
		SelectEnv:     "\nSélectionnez l'environnement %s :",
		Choice:        "Choix",
		InvalidChoice: "Choix invalide ; retour à la sélection par défaut.",
		ModePrompt:    "Mode d'exécution ([a]uto / [i]nteractif - défaut : i) ? ",
		AutoLabel:     "Mode : Automatisé",
		InterLabel:    "Mode : Interactif",
		RunStep:       "   Exécuter cette étape ? (O/n) ",
		RetryPrompt:   "   Échec de l'étape. [r]éessayer / [c]ontinuer / [s]top (défaut : r) : ",
		Failed:        "Étape échouée : %v",
		Executing:     "\nExécution : %s",
		Dashboard:     "Tableau de bord interactif mdb",
		Logs:          "Journaux",
		Stdout:        "Sortie standard",
		Stderr:        "Erreur standard",
		NoOut:         "(aucune sortie)",
		NoErr:         "(aucune erreur)",
		FinalReport:   "\nTerminé. Rapport final : %s\n",
	},
}

// ParseArgs parses CLI flags for `mdb interactive`.
func ParseArgs(args []string) (Options, error) {
	var opts Options
	fs := flag.NewFlagSet("interactive", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	fs.BoolVar(&opts.Auto, "a", false, "")
	fs.BoolVar(&opts.Auto, "auto", false, "")
	fs.BoolVar(&opts.Interactive, "i", false, "")
	fs.BoolVar(&opts.Interactive, "interactive", false, "")
	fs.StringVar(&opts.Lang, "l", "", "")
	fs.StringVar(&opts.Lang, "lang", "", "")
	if err := fs.Parse(args); err != nil {
		return opts, err
	}
	if opts.Lang != "" {
		l := strings.ToLower(strings.TrimSpace(opts.Lang))
		if l != "en" && l != "fr" {
			return opts, fmt.Errorf("unsupported language %q (expected en or fr)", opts.Lang)
		}
		opts.Lang = l
	}
	return opts, nil
}

// IsMySQLFamily reports whether an engine uses MySQL-compatible sample datasets.
func IsMySQLFamily(engine string) bool {
	switch strings.ToLower(strings.TrimSpace(engine)) {
	case "mysql", "mariadb", "percona":
		return true
	default:
		return false
	}
}

func verifierType(env catalog.Environment) string {
	if env.Category == catalog.CategoryCluster {
		return env.ID
	}
	switch strings.ToLower(env.Engine) {
	case "percona":
		return "mysql"
	case "postgresql":
		return "postgres"
	default:
		return strings.ToLower(env.Engine)
	}
}

// VerifyEnvironment runs real dbclient.NewVerifier connectivity checks for env.
func VerifyEnvironment(ctx context.Context, env catalog.Environment, client *docker.Client) (string, error) {
	ctr := env.Container
	if client != nil && ctr != "" {
		if names, err := client.PS(ctx, "name="+ctr); err == nil && len(names) > 0 {
			ctr = names[0]
		}
	}
	pass := config.DefaultConfig().RootPassword
	if cfg, err := config.Load(""); err == nil && cfg != nil {
		pass = cfg.RootPassword
	}
	vType := verifierType(env)
	v, err := dbclient.NewVerifier(vType, dbclient.Config{
		Name: env.ID, ClusterType: vType, Container: ctr, Password: pass, Executor: client,
	})
	if err != nil {
		return "", err
	}
	defer v.Close()
	health, err := v.VerifyCluster(ctx)
	var out string
	if health != nil {
		b, _ := json.MarshalIndent(health, "", "  ")
		out = string(b)
	}
	if err != nil {
		return out, err
	}
	if health != nil && health.Status == dbclient.StatusUnhealthy {
		return out, fmt.Errorf("environment %s is unhealthy", env.ID)
	}
	return out, nil
}

// BuildSteps returns the ordered wizard steps for any active catalog environment.
func BuildSteps(env catalog.Environment, lang string, verify VerifierRunner) []Step {
	fr := lang == "fr"
	pick := func(enText, frText string) string {
		if fr {
			return frText
		}
		return enText
	}
	steps := []Step{
		{
			ID: "config", Name: pick("Validate Configuration", "Valider la configuration"),
			Description: pick("Checks resolved lab configuration.", "Vérifie la configuration du laboratoire."),
			Command:     "mdb config", Args: []string{"config"},
		},
		{
			ID: "start", Name: pick("Start "+env.ID, "Démarrer "+env.ID),
			Description: pick("Starts "+env.Description+".", "Démarre "+env.Description+"."),
			Command:     "mdb up " + env.ID, Args: []string{"up", env.ID},
		},
		{
			ID: "status", Name: pick("Check Status", "Vérifier l'état"),
			Description: pick("Inspects running containers.", "Inspecte les conteneurs actifs."),
			Command:     "mdb status " + env.ID, Args: []string{"status", env.ID},
		},
	}
	if IsMySQLFamily(env.Engine) {
		ds := "employees"
		if env.ID == "mysql97" {
			ds = "sakila"
		}
		steps = append(steps, Step{
			ID: "inject", Name: pick("Inject Sample Data", "Injecter les données"),
			Description: pick("Loads "+ds+" sample dataset.", "Charge le jeu de données "+ds+"."),
			Command:     fmt.Sprintf("mdb inject %s %s", ds, env.ID), Args: []string{"inject", ds, env.ID},
		})
	}
	steps = append(steps, Step{
		ID: "verify", Name: pick("Verify Connectivity", "Vérifier la connectivité"),
		Description: pick("Runs real dbclient cluster/engine verification.", "Exécute la vérification réelle dbclient."),
		Command:     fmt.Sprintf("dbclient.VerifyCluster(%s)", env.ID),
		Run: func(ctx context.Context) (string, string, error) {
			out, err := verify(ctx, env)
			return out, "", err
		},
	})
	return steps
}

func readLine(r *bufio.Reader) string {
	line, _ := r.ReadString('\n')
	return strings.TrimSpace(line)
}

// SelectEnvironment prompts the user to pick any active standalone or cluster environment from catalog.
func SelectEnvironment(r *bufio.Reader, w io.Writer, cat *catalog.Catalog, lang string) (catalog.Environment, error) {
	s := i18n[lang]
	stand := cat.Filter(catalog.CategoryStandalone, "", true, false)
	clust := cat.Filter(catalog.CategoryCluster, "", true, false)
	fmt.Fprintln(w, s.SelectCat)
	fmt.Fprintf(w, s.CatStandalone+"\n", len(stand))
	fmt.Fprintf(w, s.CatCluster+"\n", len(clust))
	fmt.Fprintf(w, "%s [1-2 | env-id] (default: 1): ", s.Choice)
	raw := readLine(r)
	if raw != "" && raw != "1" && raw != "2" {
		if env, ok := cat.Lookup(raw); ok {
			if env.Status == catalog.StatusEOL {
				return catalog.Environment{}, fmt.Errorf("%s reached EOL on %s (use: %s)", env.ID, env.EOLDate, env.Replacement)
			}
			return env, nil
		}
	}
	list, catLabel := stand, "Standalone"
	if raw == "2" {
		list, catLabel = clust, "Cluster"
	}
	if len(list) == 0 {
		return catalog.Environment{}, errors.New("no active environments available in catalog")
	}
	fmt.Fprintf(w, s.SelectEnv+"\n", catLabel)
	for i, e := range list {
		fmt.Fprintf(w, "%2d. %-16s (%s %s) - %s\n", i+1, e.ID, e.Engine, e.Version, e.Description)
	}
	fmt.Fprintf(w, "%s [1-%d] (default: 1): ", s.Choice, len(list))
	pick := readLine(r)
	if pick == "" {
		return list[0], nil
	}
	if env, ok := cat.Lookup(pick); ok {
		if env.Status == catalog.StatusEOL {
			return catalog.Environment{}, fmt.Errorf("%s reached EOL on %s (use: %s)", env.ID, env.EOLDate, env.Replacement)
		}
		return env, nil
	}
	if idx, err := strconv.Atoi(pick); err == nil && idx >= 1 && idx <= len(list) {
		return list[idx-1], nil
	}
	fmt.Fprintln(w, s.InvalidChoice)
	if def, ok := cat.Lookup("mariadb114"); ok {
		return def, nil
	}
	return list[0], nil
}
