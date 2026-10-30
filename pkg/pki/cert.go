package pki

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type CertSpec struct {
	Name, CommonName string
	ValidDays        int
	DNSNames         []string
	IPAddresses      []net.IP
	IsCA, IsClient   bool
}

type KeyPair struct {
	Cert    *x509.Certificate
	Key     *rsa.PrivateKey
	CertPEM []byte
	KeyPEM  []byte
}

type PKIEngine struct{ BaseDir string }

func NewPKIEngine(baseDir string) *PKIEngine {
	if baseDir == "" {
		baseDir = "ssl"
	}
	return &PKIEngine{BaseDir: baseDir}
}

func genKeyPair(tmpl *x509.Certificate, parent *x509.Certificate, pKey *rsa.PrivateKey) (*KeyPair, error) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, err
	}
	serial, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return nil, err
	}
	tmpl.SerialNumber = serial

	p, k := parent, pKey
	if p == nil {
		p, k = tmpl, key
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, p, &key.PublicKey, k)
	if err != nil {
		return nil, err
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		return nil, err
	}
	cPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	kPEM := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	return &KeyPair{Cert: cert, Key: key, CertPEM: cPEM, KeyPEM: kPEM}, nil
}

func makeTemplate(spec CertSpec, isCA bool) *x509.Certificate {
	days := spec.ValidDays
	if days <= 0 {
		days = 3650
	}
	cn := spec.CommonName
	if cn == "" {
		if isCA {
			cn = spec.Name + "-CA"
		} else {
			cn = spec.Name
		}
	}
	tmpl := &x509.Certificate{
		Subject:               pkix.Name{CommonName: cn},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(time.Duration(days) * 24 * time.Hour),
		BasicConstraintsValid: true,
		DNSNames:              spec.DNSNames,
		IPAddresses:           spec.IPAddresses,
	}
	if isCA {
		tmpl.IsCA = true
		tmpl.KeyUsage = x509.KeyUsageCertSign | x509.KeyUsageCRLSign | x509.KeyUsageDigitalSignature
	} else {
		tmpl.KeyUsage = x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment
		if spec.IsClient {
			tmpl.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth}
		} else {
			tmpl.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth, x509.ExtKeyUsageClientAuth}
		}
	}
	return tmpl
}

func (p *PKIEngine) GenerateCA(spec CertSpec) (*KeyPair, error) {
	return genKeyPair(makeTemplate(spec, true), nil, nil)
}

func (p *PKIEngine) GenerateSignedCert(spec CertSpec, ca *KeyPair) (*KeyPair, error) {
	if ca == nil || ca.Cert == nil || ca.Key == nil {
		return nil, errors.New("valid CA required")
	}
	return genKeyPair(makeTemplate(spec, false), ca.Cert, ca.Key)
}

func writeSecure(path string, data []byte, perm os.FileMode) error {
	if err := os.WriteFile(path, data, perm); err != nil {
		return err
	}
	return os.Chmod(path, perm)
}

func (p *PKIEngine) SaveKeyPair(dir, certName, keyName string, kp *KeyPair, perm os.FileMode) error {
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	if perm == 0 {
		perm = 0600
	}
	if err := os.WriteFile(filepath.Join(dir, certName), kp.CertPEM, 0644); err != nil {
		return err
	}
	return writeSecure(filepath.Join(dir, keyName), kp.KeyPEM, perm)
}

func (p *PKIEngine) SaveCombinedPEM(dir, name string, certPEM, keyPEM []byte, perm os.FileMode) error {
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	if perm == 0 {
		perm = 0600
	}
	return writeSecure(filepath.Join(dir, name), append(append([]byte{}, certPEM...), keyPEM...), perm)
}

func (p *PKIEngine) VerifyCertBytes(caPEM, certPEM []byte) error {
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM(caPEM) {
		return errors.New("invalid CA")
	}
	block, _ := pem.Decode(certPEM)
	if block == nil {
		return errors.New("failed decoding PEM")
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return err
	}
	_, err = cert.Verify(x509.VerifyOptions{
		Roots:       roots,
		CurrentTime: cert.NotBefore.Add(time.Minute),
		KeyUsages:   []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	})
	return err
}

type topoSpec struct {
	sub, cn, caCert, srvCert, cliCert, combined string
	dns                                         []string
}

var (
	mariadbSpec = topoSpec{"", "MariaDB", "ca-cert.pem", "server-cert.pem", "client-cert.pem", "", []string{"localhost", "mariadb"}}
	topoMap     = map[string]topoSpec{
		"mariadb": mariadbSpec, "galera": mariadbSpec, "repli": mariadbSpec,
		"innodb":  {"innodb", "MySQL-InnoDB", "ca-cert.pem", "server-cert.pem", "", "", []string{"localhost", "mysql1", "mysql2", "mysql3"}},
		"mongo":   {"mongo", "MongoDB-RS", "ca.pem", "server.crt", "", "mongodb.pem", []string{"localhost", "mongo1", "mongo2", "mongo3"}},
		"patroni": {"patroni", "Patroni-Cluster", "ca-cert.pem", "server.crt", "", "", []string{"localhost", "etcd1", "etcd2", "etcd3", "node1", "node2", "node3", "haproxy", "pgbouncer"}},
		"pgpool":  {"pgpool", "PostgreSQL-PgPool", "ca-cert.pem", "server.crt", "", "", []string{"localhost", "pgpool", "node1", "node2", "node3"}},
	}
)

func keyName(cert string) string {
	if cert == "ca.pem" {
		return "ca-key.pem"
	}
	if strings.HasSuffix(cert, "-cert.pem") {
		return strings.Replace(cert, "-cert.pem", "-key.pem", 1)
	}
	return strings.TrimSuffix(cert, ".crt") + ".key"
}

func (p *PKIEngine) GenerateTopologyCerts(topology string) error {
	if strings.ToLower(topology) == "all" {
		for _, t := range []string{"mariadb", "innodb", "mongo", "patroni", "pgpool"} {
			if err := p.GenerateTopologyCerts(t); err != nil {
				return err
			}
		}
		return nil
	}
	spec, ok := topoMap[strings.ToLower(topology)]
	if !ok {
		return fmt.Errorf("unknown topology: %s", topology)
	}
	dir := p.BaseDir
	if spec.sub != "" {
		dir = filepath.Join(p.BaseDir, spec.sub)
	}
	save := func(name string, kp *KeyPair) error {
		return p.SaveKeyPair(dir, name, keyName(name), kp, 0600)
	}
	ips := []net.IP{net.ParseIP("127.0.0.1")}
	signAndSave := func(certName, suffix string, isClient bool, ca *KeyPair) (*KeyPair, error) {
		kp, err := p.GenerateSignedCert(CertSpec{Name: spec.cn + suffix, DNSNames: spec.dns, IPAddresses: ips, IsClient: isClient}, ca)
		if err != nil || save(certName, kp) != nil {
			return nil, err
		}
		return kp, nil
	}

	caKP, err := p.GenerateCA(CertSpec{Name: spec.cn, DNSNames: spec.dns, IPAddresses: ips})
	if err != nil || save(spec.caCert, caKP) != nil {
		return err
	}
	srvKP, err := signAndSave(spec.srvCert, "-Server", false, caKP)
	if err != nil {
		return err
	}
	if spec.cliCert != "" {
		if _, err := signAndSave(spec.cliCert, "-Client", true, caKP); err != nil {
			return err
		}
	}
	if spec.combined != "" {
		return p.SaveCombinedPEM(dir, spec.combined, srvKP.CertPEM, srvKP.KeyPEM, 0600)
	}
	return nil
}

func (p *PKIEngine) VerifyTopologyCerts(topology string) (bool, error) {
	spec, ok := topoMap[strings.ToLower(topology)]
	if !ok {
		return false, fmt.Errorf("unknown topology: %s", topology)
	}
	dir := p.BaseDir
	if spec.sub != "" {
		dir = filepath.Join(p.BaseDir, spec.sub)
	}
	ca, err := os.ReadFile(filepath.Join(dir, spec.caCert))
	if err != nil {
		return false, err
	}
	for _, c := range []string{spec.srvCert, spec.cliCert} {
		if c == "" {
			continue
		}
		leaf, err := os.ReadFile(filepath.Join(dir, c))
		if err != nil || p.VerifyCertBytes(ca, leaf) != nil {
			return false, err
		}
	}
	return true, nil
}
