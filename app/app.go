package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"sync"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

// App is bound to the frontend: every exported method is callable from JavaScript.
type App struct {
	ctx    context.Context
	mu     sync.Mutex
	tablet *Tablet
	mods   []Mod
}

func NewApp() *App { return &App{} }

func (a *App) startup(ctx context.Context) { a.ctx = ctx }

func (a *App) shutdown(context.Context) { a.tablet.Close() }

// log sends a line to the progress view.
func (a *App) log(line string) { runtime.EventsEmit(a.ctx, "log", line) }

// step sends a step heading (a message key the frontend translates, plus an optional detail).
func (a *App) step(key, detail string) { runtime.EventsEmit(a.ctx, "step", key, detail) }

// CatalogResult is what Catalog returns.
type CatalogResult struct {
	Mods     []Mod    `json:"mods"`
	Warnings []string `json:"warnings"`
}

// Catalog loads the list of mods and add-ons (online).
func (a *App) Catalog() (CatalogResult, error) {
	mods, warn, err := loadCatalog()
	if err != nil {
		return CatalogResult{}, err
	}
	a.mu.Lock()
	a.mods = mods
	a.mu.Unlock()
	return CatalogResult{Mods: mods, Warnings: warn}, nil
}

// ConnectResult tells the frontend whether the root password is needed.
type ConnectResult struct {
	NeedPassword bool     `json:"needPassword"`
	Installed    []string `json:"installed"` // mod ids
	Vellum       bool     `json:"vellum"`
	NeedsRestore bool     `json:"needsRestore"` // Vellum packages present but the OS update removed their files
	Model        string   `json:"model"`
}

// Connect logs in (password only the first time) and reads what is installed.
func (a *App) Connect(host, password string) (ConnectResult, error) {
	host = strings.TrimSpace(host)
	if host == "" {
		host = "10.11.99.1"
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	a.tablet.Close()
	a.tablet = nil
	t, needPw, err := connect(host, password)
	if needPw && err == nil {
		return ConnectResult{NeedPassword: true}, nil
	}
	if err != nil {
		return ConnectResult{NeedPassword: needPw}, err
	}
	a.tablet = t
	return a.status()
}

// Refresh reads the tablet state again.
func (a *App) Refresh() (ConnectResult, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tablet == nil {
		return ConnectResult{}, errors.New("not connected")
	}
	return a.status()
}

var pkgVersion = regexp.MustCompile(`-[0-9][^-]*-r[0-9]+$`)

func (a *App) status() (ConnectResult, error) {
	t := a.tablet
	r := ConnectResult{}
	r.Vellum = t.ok("[ -x /home/root/.vellum/bin/vellum ]")
	installed := map[string]bool{}
	if r.Vellum {
		out, _ := t.run("/home/root/.vellum/bin/vellum list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1", nil, nil)
		for _, l := range strings.Fields(out) {
			installed[pkgVersion.ReplaceAllString(l, "")] = true
		}
	}
	for i := range a.mods {
		m := &a.mods[i]
		if m.Type == "vellum" {
			m.Installed = installed[m.Package]
		} else if m.Check != "" {
			m.Installed = t.ok(m.Check)
		}
		if m.Installed {
			r.Installed = append(r.Installed, m.ID)
		}
	}
	r.NeedsRestore = len(installed) > 0 && t.ok("[ ! -x /usr/lib/rmpp-preload/launch ] && [ -x /home/root/.vellum/bin/vellum ]")
	if out, err := t.run("grep -hm1 '^IMG_VERSION=' /usr/share/remarkable/update.conf /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"'", nil, nil); err == nil {
		if v := strings.TrimSpace(out); v != "" {
			r.Model = "OS " + v
		}
	}
	return r, nil
}

// Install installs the chosen mods (ids from the catalog), in the same steps as install-rmpp.sh.
func (a *App) Install(ids []string) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	t := a.tablet
	if t == nil {
		return errors.New("not connected")
	}
	byID := map[string]Mod{}
	for _, m := range a.mods {
		byID[m.ID] = m
	}
	var packages []string
	var releases []Mod
	add := func(p string) {
		for _, q := range packages {
			if q == p {
				return
			}
		}
		packages = append(packages, p)
	}
	for _, id := range ids {
		m, ok := byID[id]
		if !ok {
			return fmt.Errorf("not in the catalog: %s", id)
		}
		if m.Type == "vellum" {
			add(m.Package)
		} else {
			releases = append(releases, m)
		}
		for _, d := range m.Needs {
			add(d)
		}
	}

	// 1. Vellum, its bootstrap checked against the hash in Vellum's README.
	if !t.ok("[ -x /home/root/.vellum/bin/vellum ]") {
		a.step("vellum", "")
		boot, err := fetch(bootstrapURL)
		if err != nil {
			return err
		}
		readme, err := fetch(vellumREADME)
		if err != nil {
			return err
		}
		m := regexp.MustCompile(`echo "([0-9a-f]{64})  bootstrap\.sh"`).FindSubmatch(readme)
		sum := sha256.Sum256(boot)
		got := hex.EncodeToString(sum[:])
		if m == nil || string(m[1]) != got {
			return fmt.Errorf("Vellum bootstrap checksum mismatch (%s)", got)
		}
		if _, err := t.run("cat > /tmp/vellum-bootstrap.sh && sh /tmp/vellum-bootstrap.sh; r=$?; rm -f /tmp/vellum-bootstrap.sh; exit $r",
			bytes.NewReader(boot), a.log); err != nil {
			return fmt.Errorf("Vellum installation failed: %w", err)
		}
	}

	// 2. This package repository and its signing key (downloaded here: the tablet needs no TLS certificates).
	a.step("repo", "")
	key, err := fetch(repoURL + "/lorancecall-rmpp.rsa.pub")
	if err != nil {
		return err
	}
	if _, err := t.run("cat > /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub", bytes.NewReader(key), a.log); err != nil {
		return err
	}
	if _, err := t.run(fmt.Sprintf("grep -qxF '%[1]s' /home/root/.vellum/etc/apk/repositories || echo '%[1]s' >> /home/root/.vellum/etc/apk/repositories", repoURL), nil, a.log); err != nil {
		return err
	}

	// 3. Vellum packages, then release mods. The tablet's screen restarts once or twice.
	if len(packages) > 0 {
		a.step("installing", strings.Join(packages, " "))
		if _, err := t.run("/home/root/.vellum/bin/vellum update && /home/root/.vellum/bin/vellum add "+strings.Join(packages, " "), nil, a.log); err != nil {
			return fmt.Errorf("installation failed: %w", err)
		}
	}
	for _, m := range releases {
		a.step("release", m.ID)
		dir := "/home/root/.cache/rmpp-mods/" + m.ID
		if _, err := t.run("rm -rf "+dir+" && mkdir -p "+dir, nil, a.log); err != nil {
			return err
		}
		for _, asset := range m.Assets {
			data, err := fetch("https://github.com/" + m.Repo + "/releases/latest/download/" + asset)
			if err != nil {
				return fmt.Errorf("could not download %s: %w", asset, err)
			}
			if _, err := t.run("cat > "+dir+"/"+asset, bytes.NewReader(data), nil); err != nil {
				return err
			}
		}
		if _, err := t.run("cd "+dir+" && sh rmpp-install.sh; r=$?; cd / && rm -rf "+dir+"; exit $r", nil, a.log); err != nil {
			return fmt.Errorf("installation failed (%s): %w", m.ID, err)
		}
	}

	// 4. After a reMarkable OS update the files in the root file system are gone: restore them.
	if t.ok("[ ! -x /usr/lib/rmpp-preload/launch ] && [ -x /home/root/.vellum/bin/vellum ] && /home/root/.vellum/bin/vellum list 2>/dev/null | grep -qF '[installed]'") {
		if err := a.reenable(); err != nil {
			return err
		}
	}
	a.step("done", "")
	return nil
}

// Restore runs `vellum reenable` (after a reMarkable OS update).
func (a *App) Restore() error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tablet == nil {
		return errors.New("not connected")
	}
	if err := a.reenable(); err != nil {
		return err
	}
	a.step("done", "")
	return nil
}

func (a *App) reenable() error {
	a.step("reenable", "")
	if _, err := a.tablet.run("/home/root/.vellum/bin/vellum reenable", nil, a.log); err != nil {
		return fmt.Errorf("vellum reenable failed: %w", err)
	}
	return nil
}

// Remove removes Vellum packages of the given mod ids (`vellum del`).
func (a *App) Remove(ids []string) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tablet == nil {
		return errors.New("not connected")
	}
	var pkgs []string
	for _, m := range a.mods {
		for _, id := range ids {
			if m.ID == id && m.Type == "vellum" && m.Package != "" {
				pkgs = append(pkgs, m.Package)
			}
		}
	}
	if len(pkgs) == 0 {
		return errors.New("nothing to remove (only Vellum packages can be removed here)")
	}
	a.step("removing", strings.Join(pkgs, " "))
	if _, err := a.tablet.run("/home/root/.vellum/bin/vellum del "+strings.Join(pkgs, " "), nil, a.log); err != nil {
		return fmt.Errorf("removal failed: %w", err)
	}
	a.step("done", "")
	return nil
}
