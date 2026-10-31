package pki

import (
	"crypto/x509"
	"net"
	"os"
	"path/filepath"
	"testing"
)

func TestPKIEngine_Lifecycle(t *testing.T) {
	d := t.TempDir()
	e := NewPKIEngine(d)
	ca, err := e.GenerateCA(CertSpec{Name: "ClusterRoot", ValidDays: 365, DNSNames: []string{"localhost"}})
	if err != nil || !ca.Cert.IsCA || ca.Key.N.BitLen() != 2048 {
		t.Fatalf("CA fail: %v", err)
	}
	srv, err := e.GenerateSignedCert(CertSpec{Name: "srv", DNSNames: []string{"localhost"}, IPAddresses: []net.IP{net.ParseIP("127.0.0.1")}}, ca)
	if err != nil || e.VerifyCertBytes(ca.CertPEM, srv.CertPEM) != nil {
		t.Fatalf("srv fail: %v", err)
	}
	cli, err := e.GenerateSignedCert(CertSpec{Name: "cli", IsClient: true}, ca)
	if err != nil || len(cli.Cert.ExtKeyUsage) == 0 || cli.Cert.ExtKeyUsage[0] != x509.ExtKeyUsageClientAuth || e.VerifyCertBytes(ca.CertPEM, cli.CertPEM) != nil {
		t.Fatalf("cli fail: %v", err)
	}
	other, _ := e.GenerateCA(CertSpec{Name: "Other"})
	if err := e.VerifyCertBytes(other.CertPEM, srv.CertPEM); err == nil {
		t.Fatal("expected mismatch err")
	}
	if err := e.SaveKeyPair(d, "ca.crt", "ca.key", ca, 0600); err != nil {
		t.Fatal(err)
	}
	if err := e.SaveCombinedPEM(d, "b.pem", ca.CertPEM, ca.KeyPEM, 0600); err != nil {
		t.Fatal(err)
	}
	if s, err := os.Stat(filepath.Join(d, "b.pem")); err != nil || s.Size() == 0 {
		t.Fatal(err)
	}
}

func TestPKIEngine_Topologies(t *testing.T) {
	d := t.TempDir()
	e := NewPKIEngine(d)
	for _, topo := range []string{"mariadb", "innodb", "mongo", "patroni", "pgpool"} {
		if err := e.GenerateTopologyCerts(topo); err != nil {
			t.Fatalf("gen %s: %v", topo, err)
		}
		if ok, err := e.VerifyTopologyCerts(topo); !ok || err != nil {
			t.Fatalf("verify %s: %v", topo, err)
		}
	}
	if err := e.GenerateTopologyCerts("all"); err != nil {
		t.Fatal(err)
	}
	if ok, err := e.VerifyTopologyCerts("all"); !ok || err != nil {
		t.Fatalf("verify all failed: %v", err)
	}
	if _, err := e.VerifyTopologyCerts("unknown"); err == nil {
		t.Fatal("expected err")
	}

	// Test corrupted cert returns an error
	tamperPath := filepath.Join(d, "server-cert.pem")
	if err := os.WriteFile(tamperPath, []byte("invalid-cert-bytes"), 0644); err != nil {
		t.Fatal(err)
	}
	if ok, err := e.VerifyTopologyCerts("mariadb"); ok || err == nil {
		t.Fatal("expected verify failure with non-nil error for tampered cert")
	}

	// Test invalid directory write returns error in GenerateTopologyCerts
	badDir := filepath.Join(d, "file_blocking_dir")
	if err := os.WriteFile(badDir, []byte("blocker"), 0644); err != nil {
		t.Fatal(err)
	}
	badEngine := NewPKIEngine(badDir)
	if err := badEngine.GenerateTopologyCerts("mariadb"); err == nil {
		t.Fatal("expected error when writing to invalid directory")
	}
}
