package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/crypto/ssh"
)

// The same key file as the shell installers (~/.ssh/id_ed25519_rmpp), so either can be used afterwards.
func keyPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".ssh", "id_ed25519_rmpp")
}

// loadOrCreateKey returns the signer and the authorized_keys line of the rmpp key, creating the key if needed.
func loadOrCreateKey() (ssh.Signer, string, error) {
	p := keyPath()
	if data, err := os.ReadFile(p); err == nil {
		s, err := ssh.ParsePrivateKey(data)
		if err != nil {
			return nil, "", fmt.Errorf("%s: %w", p, err)
		}
		return s, string(ssh.MarshalAuthorizedKey(s.PublicKey())), nil
	}
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, "", err
	}
	block, err := ssh.MarshalPrivateKey(priv, "rmpp")
	if err != nil {
		return nil, "", err
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return nil, "", err
	}
	if err := os.WriteFile(p, pem.EncodeToMemory(block), 0o600); err != nil {
		return nil, "", err
	}
	s, err := ssh.NewSignerFromKey(priv)
	if err != nil {
		return nil, "", err
	}
	pub := ssh.MarshalAuthorizedKey(s.PublicKey())
	_ = os.WriteFile(p+".pub", []byte(strings.TrimSpace(string(pub))+" rmpp\n"), 0o644)
	return s, string(pub), nil
}

// Host keys are remembered on first use (like StrictHostKeyChecking=accept-new) in the app's own file.
func knownHostsPath() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = os.TempDir()
	}
	return filepath.Join(dir, "rmpp-setup", "known_hosts")
}

var errHostKeyChanged = errors.New("host key changed")

func hostKeyCallback(host string) ssh.HostKeyCallback {
	return func(_ string, _ net.Addr, key ssh.PublicKey) error {
		p := knownHostsPath()
		line := host + " " + strings.TrimSpace(string(ssh.MarshalAuthorizedKey(key)))
		data, _ := os.ReadFile(p)
		for _, l := range strings.Split(string(data), "\n") {
			h, k, ok := strings.Cut(l, " ")
			if !ok || h != host {
				continue
			}
			if host+" "+k == line {
				return nil
			}
			return fmt.Errorf("%w for %s: if the tablet was reset, remove its line from %s", errHostKeyChanged, host, p)
		}
		_ = os.MkdirAll(filepath.Dir(p), 0o700)
		f, err := os.OpenFile(p, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
		if err != nil {
			return nil
		}
		defer f.Close()
		_, _ = f.WriteString(line + "\n")
		return nil
	}
}

// Tablet is an SSH connection as root.
type Tablet struct {
	Host   string
	client *ssh.Client
}

// ConnectOptions are the "Advanced" settings of the connect step; the zero value is the normal way.
type ConnectOptions struct {
	KeyPath      string `json:"keyPath"`      // private key file; empty = ~/.ssh/id_ed25519_rmpp (made if missing)
	Port         int    `json:"port"`         // SSH port; 0 = 22
	PasswordOnly bool   `json:"passwordOnly"` // log in with the root password every time, add no key
}

func dial(addr, known string, auth ssh.AuthMethod) (*ssh.Client, error) {
	cfg := &ssh.ClientConfig{
		User: "root", Auth: []ssh.AuthMethod{auth},
		HostKeyCallback: hostKeyCallback(known), Timeout: 8 * time.Second,
	}
	return ssh.Dial("tcp", addr, cfg)
}

// loadKey reads a private key file the user picked (it must exist; passphrase-protected keys are not supported).
func loadKey(p string) (ssh.Signer, string, error) {
	data, err := os.ReadFile(p)
	if err != nil {
		return nil, "", err
	}
	s, err := ssh.ParsePrivateKey(data)
	var pp *ssh.PassphraseMissingError
	if errors.As(err, &pp) {
		return nil, "", fmt.Errorf("%s is protected by a passphrase; use a key without one", p)
	}
	if err != nil {
		return nil, "", fmt.Errorf("%s: %w", p, err)
	}
	return s, string(ssh.MarshalAuthorizedKey(s.PublicKey())), nil
}

// connect logs in as root. Normally with the rmpp key; if the tablet does not know it yet, the root password
// (shown on the tablet in Settings > General > Help > About > Copyrights and licenses) is used once to add the
// key. auth tells how it logged in: "key" or "password". needPassword: ask the user and call again.
func connect(host, password string, o ConnectOptions) (t *Tablet, auth string, needPassword bool, err error) {
	port := o.Port
	if port == 0 {
		port = 22
	}
	addr := net.JoinHostPort(host, fmt.Sprint(port))
	known := host
	if port != 22 {
		known = addr
	}
	if o.PasswordOnly {
		if password == "" {
			return nil, "", true, nil
		}
		c, err := dial(addr, known, ssh.Password(password))
		if err != nil {
			return nil, "", true, err
		}
		return &Tablet{Host: host, client: c}, "password", false, nil
	}
	var signer ssh.Signer
	var pub string
	if o.KeyPath != "" {
		signer, pub, err = loadKey(o.KeyPath)
	} else {
		signer, pub, err = loadOrCreateKey()
	}
	if err != nil {
		return nil, "", false, err
	}
	if c, err := dial(addr, known, ssh.PublicKeys(signer)); err == nil {
		return &Tablet{Host: host, client: c}, "key", false, nil
	} else if !strings.Contains(err.Error(), "unable to authenticate") {
		return nil, "", false, err // not reachable, or the host key changed: a password would not help
	}
	if password == "" {
		return nil, "", true, nil
	}
	c, err := dial(addr, known, ssh.Password(password))
	if err != nil {
		return nil, "", true, err
	}
	tab := &Tablet{Host: host, client: c}
	if _, err := tab.run("umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys", strings.NewReader(pub), nil); err != nil {
		c.Close()
		return nil, "", false, fmt.Errorf("adding the key: %w", err)
	}
	c.Close()
	c, err = dial(addr, known, ssh.PublicKeys(signer))
	if err != nil {
		return nil, "", false, fmt.Errorf("the key was not accepted: %w", err)
	}
	return &Tablet{Host: host, client: c}, "key", false, nil
}

func (t *Tablet) Close() {
	if t != nil && t.client != nil {
		t.client.Close()
	}
}

// run executes a shell command; stdin is optional. Output goes to log line by line when log is set, and is
// returned in full.
func (t *Tablet) run(cmd string, stdin io.Reader, log func(string)) (string, error) {
	s, err := t.client.NewSession()
	if err != nil {
		return "", err
	}
	defer s.Close()
	if stdin != nil {
		s.Stdin = stdin
	}
	var buf bytes.Buffer
	w := io.Writer(&buf)
	if log != nil {
		w = io.MultiWriter(&buf, &lineWriter{log: log})
	}
	s.Stdout, s.Stderr = w, w
	err = s.Run(cmd)
	return buf.String(), err
}

// ok runs a test command and reports whether it exited 0.
func (t *Tablet) ok(cmd string) bool {
	_, err := t.run(cmd, nil, nil)
	return err == nil
}

type lineWriter struct {
	log  func(string)
	part []byte
}

func (w *lineWriter) Write(p []byte) (int, error) {
	w.part = append(w.part, p...)
	for {
		i := bytes.IndexAny(w.part, "\r\n")
		if i < 0 {
			break
		}
		if line := strings.TrimRight(string(w.part[:i]), " "); line != "" {
			w.log(line)
		}
		w.part = w.part[i+1:]
	}
	return len(p), nil
}
