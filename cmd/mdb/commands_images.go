package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

type imageSpec struct {
	Image      string   `json:"image"`
	Kind       string   `json:"kind"`
	Group      string   `json:"group"`
	Source     string   `json:"source"`
	Context    string   `json:"context,omitempty"`
	Topologies []string `json:"topologies"`
}

type imageStatus struct {
	imageSpec
	Status  string `json:"status"`
	Present bool   `json:"present"`
}

func cImg(img, grp, df, dir, topos string) imageSpec {
	return imageSpec{img, "custom", grp, df, dir, strings.Split(topos, ",")}
}

func uImg(grp, img, topos string) imageSpec {
	return imageSpec{img, "upstream", grp, "registry", "", strings.Split(topos, ",")}
}

func sImg(img, topos string) imageSpec { return uImg("standalone", img, topos) }
func kImg(img, topos string) imageSpec { return uImg("clusters", img, topos) }
func hImg(img, topos string) imageSpec { return uImg("helpers", img, topos) }

var e2eImages = []imageSpec{
	cImg("mariadb_ssh:004", "mariadb", "Dockerfile", ".", "galera,repli,bench"),
	cImg("multi-db-bucardo-pg17:latest", "bucardo", "scripts/bucardo/Dockerfile.pg", "scripts/bucardo", "bucardo"),
	cImg("multi-db-bucardo-daemon:latest", "bucardo", "scripts/bucardo/Dockerfile", "scripts/bucardo", "bucardo"),
	cImg("patroni-rhel8-etcd:latest", "patroni", "scripts/patroni/Dockerfile.etcd", ".", "patroni"),
	cImg("patroni-rhel8-postgresql:latest", "patroni", "scripts/patroni/Dockerfile.postgresql", ".", "patroni"),
	cImg("patroni-rhel8-haproxy:latest", "patroni", "scripts/patroni/Dockerfile.haproxy", ".", "patroni"),
	cImg("multi-db-pgbench-sysbench:latest", "bench", "scripts/Dockerfile.bench", "scripts", "bench"),
	sImg("traefik:v3", "standalone"),
	sImg("mysql:9.7", "mysql97"),
	sImg("mysql:8.4", "mysql84,innodb"),
	sImg("mariadb:12.3", "mariadb123"),
	sImg("mariadb:11.8", "mariadb118"),
	sImg("mariadb:11.4", "mariadb114"),
	sImg("mariadb:10.11", "mariadb1011"),
	sImg("percona/percona-server:8.4", "percona84"),
	sImg("postgres:18", "postgres18,pg18-streaming,pg18-logical,pg18-birep"),
	sImg("postgres:17", "postgres17,pg17-baseline,pg-streaming,pg-logical,pg-birep,pgpool"),
	sImg("postgres:16", "postgres16"),
	sImg("postgres:15", "postgres15"),
	kImg("haproxy:lts", "galera,repli,innodb,mongo,mongo8,pgpool"),
	kImg("haproxy:lts-alpine", "pg-birep,pg18-birep,pgedge,cockroach,yugabyte"),
	kImg("mongo:7.0", "mongo"),
	kImg("mongo:8.0", "mongo8"),
	kImg("pgpool/pgpool:4.4.3", "pgpool"),
	kImg("ghcr.io/pgedge/pgedge-postgres:17-spock5-minimal", "pgedge"),
	kImg("citusdata/citus:14.2.0-pg17", "citus"),
	kImg("cockroachdb/cockroach:latest-v25.4", "cockroach"),
	kImg("yugabytedb/yugabyte:2026.1.3.0-b100", "yugabyte"),
	kImg("dbinvent/yt:1.21.3", "yt-cluster"),
	hImg("postgres:17-alpine", "test-patroni,test-pgpool"),
	hImg("alpine:latest", "clean,gen-pki"),
}

func selectImages(kind, group string) ([]imageSpec, error) {
	g := strings.ToLower(strings.TrimSpace(group))
	if g == "" {
		g = "all"
	}
	var out []imageSpec
	for _, s := range e2eImages {
		if s.Kind == kind && (g == "all" || s.Group == g) {
			out = append(out, s)
		}
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("unknown %s group %q", kind, group)
	}
	return out, nil
}

func inspectImageStatuses(ctx context.Context, client *docker.Client) ([]imageStatus, int, error) {
	local, err := client.ListLocalImages(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, present := make([]imageStatus, 0, len(e2eImages)), 0
	for _, s := range e2eImages {
		ok, st := local[s.Image], "MISSING"
		if ok {
			st, present = "PRESENT", present+1
		}
		items = append(items, imageStatus{s, st, ok})
	}
	return items, present, nil
}

func runImagesCmd(ctx context.Context, client *docker.Client, args []string, stdout io.Writer) error {
	const usage = "usage: mdb images <list [--json]|build [all|mariadb|bucardo|patroni|bench]|pull [all|standalone|clusters|helpers]|check>"
	if len(args) == 0 {
		return errors.New(usage)
	}
	target := "all"
	if len(args) > 1 {
		target = args[1]
	}
	switch strings.ToLower(args[0]) {
	case "list":
		fs := flag.NewFlagSet("images list", flag.ContinueOnError)
		fs.SetOutput(io.Discard)
		jsonF := fs.Bool("json", false, "")
		flags, _ := splitFlagsAndArgs(args[1:], map[string]bool{"json": true})
		if err := fs.Parse(flags); err != nil {
			return err
		}
		items, present, err := inspectImageStatuses(ctx, client)
		if err != nil {
			return err
		}
		if *jsonF {
			b, err := json.MarshalIndent(items, "", "  ")
			if err == nil {
				fmt.Fprintln(stdout, string(b))
			}
			return err
		}
		tw := tabwriter.NewWriter(stdout, 0, 4, 2, ' ', 0)
		fmt.Fprintln(tw, "IMAGE\tKIND\tGROUP\tSOURCE\tTOPOLOGIES\tSTATUS")
		for _, it := range items {
			fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\t%s\n", it.Image, it.Kind, it.Group, it.Source, strings.Join(it.Topologies, ","), it.Status)
		}
		_ = tw.Flush()
		fmt.Fprintf(stdout, "\nTotal: %d images (%d PRESENT, %d MISSING)\n", len(items), present, len(items)-present)
		return nil
	case "build", "pull":
		isBuild, kind := strings.EqualFold(args[0], "build"), "upstream"
		if isBuild {
			kind = "custom"
		}
		specs, err := selectImages(kind, target)
		if err != nil {
			return err
		}
		for i, s := range specs {
			if isBuild {
				fmt.Fprintf(stdout, "[%d/%d] Building %s (%s)...\n", i+1, len(specs), s.Image, s.Source)
				err = client.BuildImageFile(ctx, s.Image, s.Source, s.Context)
			} else {
				fmt.Fprintf(stdout, "[%d/%d] Pulling %s...\n", i+1, len(specs), s.Image)
				err = client.PullImage(ctx, s.Image)
			}
			if err != nil {
				return err
			}
		}
		fmt.Fprintf(stdout, "Processed %d %s image(s) successfully.\n", len(specs), kind)
		return nil
	case "check":
		items, present, err := inspectImageStatuses(ctx, client)
		if err != nil {
			return err
		}
		if present == len(items) {
			fmt.Fprintf(stdout, "OK: all %d/%d E2E images are PRESENT locally.\n", present, len(items))
			return nil
		}
		var missing []string
		for _, it := range items {
			if !it.Present {
				missing = append(missing, it.Image)
				fmt.Fprintf(stdout, "MISSING  %-52s (%s/%s: %s)\n", it.Image, it.Kind, it.Group, it.Source)
			}
		}
		return fmt.Errorf("missing %d/%d E2E image(s): %s", len(missing), len(items), strings.Join(missing, ", "))
	default:
		return fmt.Errorf("unknown images action %q\n%s", args[0], usage)
	}
}
