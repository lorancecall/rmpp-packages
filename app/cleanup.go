package main

import (
	"errors"
	"fmt"
	"path"
	"sort"
	"strings"
)

// "Clean up leftovers": rmpp add-ons keep their system files on the root file system (/usr/lib, systemd units), so a
// factory reset (which wipes /home, Vellum included) leaves them behind with no package to remove them, and xochitl
// keeps loading them. This finds every rmpp system file whose package is not installed and removes it.

// Where rmpp add-ons put system files (see the VELBUILDs and rmpp-hwr's installer). rmpp-preload 0.2+ keeps all of
// them under /usr/lib/rmpp plus xochitl's drop-in; the other paths are from older versions.
const leftoverGlobs = "/usr/lib/rmpp/* /usr/lib/rmpp/.trash /usr/lib/rmpp/preload.d/* /usr/lib/rmpp/env.d/* " +
	"/usr/lib/rmpp/boot.d/* /usr/lib/rmpp/units/* " +
	"/usr/lib/rmpp-* /usr/bin/rmpp-* /usr/lib/rmpp-preload.d/* " +
	"/usr/lib/systemd/system/rmpp-* /usr/lib/systemd/system/multi-user.target.wants/rmpp-* " +
	"/usr/lib/systemd/system/xochitl.service.d/zz-rmpp-*"

// rmppDir: rmpp-preload 0.2+'s folder; its own entries belong to rmpp-preload, the others to an add-on.
const rmppDir = "/usr/lib/rmpp"

var rmppPreloadEntries = map[string]bool{"launch": true, "restart": true, "preload.d": true, "env.d": true,
	"boot.d": true, "units": true, ".trash": true}

// linkOwner: NN-<package>.so, NN-<package> (boot hook) or <package>.env -> <package>
func linkOwner(base string) string {
	name := strings.TrimSuffix(strings.TrimSuffix(base, ".so"), ".env")
	if i := strings.Index(name, "-"); i >= 0 && i <= 3 && strings.Trim(name[:i], "0123456789") == "" {
		name = name[i+1:]
	}
	return name
}

// systemd units named differently from their package.
var unitOwner = map[string]string{
	"rmpp-bluetooth": "rmpp-bt", "rmpp-bt-reconnect": "rmpp-bt",
	"rmpp-tailscaled": "rmpp-tailscale", "rmpp-tailscale-ssh": "rmpp-tailscale",
}

// leftoverOwner says which package a system file belongs to.
func leftoverOwner(p string) string {
	base := path.Base(p)
	dir := path.Dir(p)
	switch {
	case p == rmppDir:
		return "rmpp-preload"
	case dir == rmppDir: // launch, restart, preload.d, ... or an add-on's folder
		if rmppPreloadEntries[base] {
			return "rmpp-preload"
		}
		return base
	case dir == rmppDir+"/preload.d" || dir == rmppDir+"/env.d" || dir == rmppDir+"/boot.d":
		return linkOwner(base)
	case dir == rmppDir+"/units": // units/<package>/
		return base
	case p == "/usr/lib/rmpp-preload" || p == "/usr/lib/rmpp-preload.d" || strings.HasPrefix(base, "zz-rmpp-preload"):
		return "rmpp-preload"
	case dir == "/usr/lib/rmpp-preload.d": // NN-<package>.so
		name := strings.TrimSuffix(base, ".so")
		if i := strings.Index(name, "-"); i >= 0 {
			name = name[i+1:]
		}
		return name
	case strings.HasPrefix(dir, "/usr/lib/systemd/system"): // rmpp-x.service, rmpp-x@.service, rmpp-x.socket
		name := strings.TrimSuffix(base, path.Ext(base))
		name = strings.TrimSuffix(name, "@")
		if o, ok := unitOwner[name]; ok {
			return o
		}
		return name
	default: // /usr/lib/<package>, /usr/bin/<package>
		return base
	}
}

// CleanupPlan is what "Clean up leftovers" will remove.
type CleanupPlan struct {
	Owners   []string `json:"owners"`   // packages whose files are left without the package
	Files    []string `json:"files"`    // the files and folders to remove
	Kept     []string `json:"kept"`     // installed packages: their files stay
	Restart  bool     `json:"restart"`  // xochitl restarts (an add-on or rmpp-preload is removed)
	Units    []string `json:"units"`    // systemd units stopped first
	Commands []string `json:"commands"` // the shell commands, in order
}

// planCleanup works only from the tablet's file listing and the installed Vellum packages, so it can be tested
// without a tablet.
func planCleanup(listing []string, installed map[string]bool) CleanupPlan {
	p := CleanupPlan{}
	owners, kept := map[string]bool{}, map[string]bool{}
	units := map[string]bool{}
	for _, f := range listing {
		f = strings.TrimSuffix(strings.TrimSpace(f), "/")
		if f == "" || !strings.HasPrefix(f, "/usr/") {
			continue
		}
		o := leftoverOwner(f)
		if installed[o] {
			kept[o] = true
			continue
		}
		owners[o] = true
		p.Files = append(p.Files, f)
		if strings.HasPrefix(f, "/usr/lib/systemd/system/rmpp-") && !strings.Contains(f, "@") {
			units[path.Base(f)] = true
		}
		if o == "rmpp-preload" || strings.HasPrefix(f, "/usr/lib/rmpp-preload.d/") || strings.HasPrefix(f, rmppDir+"/preload.d/") {
			p.Restart = true
		}
	}
	// a removed rmpp-preload takes its folders along: remove /usr/lib/rmpp (and the old preload.d) as a whole
	if owners["rmpp-preload"] {
		var fs []string
		hasRmpp := false
		for _, f := range p.Files {
			if f == rmppDir || strings.HasPrefix(f, rmppDir+"/") {
				hasRmpp = true
				continue
			}
			if !strings.HasPrefix(f, "/usr/lib/rmpp-preload.d/") {
				fs = append(fs, f)
			}
		}
		if hasRmpp {
			fs = append(fs, rmppDir)
		}
		p.Files = fs
	}
	for o := range owners {
		p.Owners = append(p.Owners, o)
	}
	for o := range kept {
		p.Kept = append(p.Kept, o)
	}
	for u := range units {
		p.Units = append(p.Units, u)
	}
	sort.Strings(p.Owners)
	sort.Strings(p.Kept)
	sort.Strings(p.Files)
	sort.Strings(p.Units)
	if len(p.Files) == 0 {
		return p
	}
	c := []string{}
	if len(p.Units) > 0 {
		c = append(c, "systemctl stop "+strings.Join(p.Units, " ")+" 2>/dev/null")
	}
	c = append(c, "mount -o remount,rw /", "rm -rf "+strings.Join(p.Files, " "), "sync", "systemctl daemon-reload")
	if p.Restart {
		c = append(c, "systemctl reset-failed xochitl 2>/dev/null", "systemctl restart xochitl", "sleep 3")
	}
	c = append(c, "mount -o remount,ro / || true")
	p.Commands = []string{strings.Join(c, "; ")}
	return p
}

// supportedDevice: removal and cleanup only run where the add-ons were made for (reMarkable Paper Pro, OS 3.29),
// detected like Vellum does (the SoC machine name "Ferrari").
func supportedDevice(machine, version string) error {
	if !strings.Contains(machine, "Ferrari") {
		return fmt.Errorf("this is not a reMarkable Paper Pro (%q): nothing was changed", strings.TrimSpace(machine))
	}
	if !strings.HasPrefix(strings.TrimSpace(version), "3.29.") {
		return fmt.Errorf("the rmpp add-ons are made for OS 3.29, this tablet runs %q: nothing was changed", strings.TrimSpace(version))
	}
	return nil
}

func (t *Tablet) checkSupported() error {
	machine, _ := t.run("cat /sys/devices/soc0/machine 2>/dev/null", nil, nil)
	version, _ := t.run("grep -hm1 '^IMG_VERSION=' /usr/share/remarkable/update.conf /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"'", nil, nil)
	return supportedDevice(machine, version)
}

func (a *App) cleanupPlan() (CleanupPlan, error) {
	t := a.tablet
	if err := t.checkSupported(); err != nil {
		return CleanupPlan{}, err
	}
	out, _ := t.run("ls -d "+leftoverGlobs+" 2>/dev/null", nil, nil)
	installed := map[string]bool{}
	if t.ok("[ -x " + vellumBin + " ]") {
		l, err := t.run(vellumBin+" list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1", nil, nil)
		if err != nil {
			return CleanupPlan{}, fmt.Errorf("reading the installed packages: %w", err)
		}
		for _, n := range strings.Fields(l) {
			installed[pkgVersion.ReplaceAllString(n, "")] = true
		}
	}
	return planCleanup(strings.Fields(out), installed), nil
}

// PlanCleanup shows which leftover system files would be removed; nothing is changed.
func (a *App) PlanCleanup() (CleanupPlan, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tablet == nil {
		return CleanupPlan{}, errors.New("not connected")
	}
	return a.cleanupPlan()
}

// Cleanup removes the leftover system files (worked out again here, to match the tablet now).
func (a *App) Cleanup() error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tablet == nil {
		return errors.New("not connected")
	}
	p, err := a.cleanupPlan()
	if err != nil {
		return err
	}
	if len(p.Files) == 0 {
		return errors.New("no leftover rmpp system files")
	}
	a.step("cleaning", strings.Join(p.Owners, ", "))
	for _, c := range p.Commands {
		a.log("$ " + c)
		if _, err := a.tablet.run(c, nil, a.log); err != nil {
			return fmt.Errorf("cleanup failed: %w", err)
		}
	}
	a.step("done", "")
	return nil
}
