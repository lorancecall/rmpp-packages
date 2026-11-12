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

// Where rmpp add-ons put system files (see the VELBUILDs and rmpp-hwr's installer).
const leftoverGlobs = "/usr/lib/rmpp-* /usr/bin/rmpp-* /usr/lib/rmpp-preload.d/* " +
	"/usr/lib/systemd/system/rmpp-* /usr/lib/systemd/system/multi-user.target.wants/rmpp-* " +
	"/usr/lib/systemd/system/xochitl.service.d/zz-rmpp-*"

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
		if o == "rmpp-preload" || strings.HasPrefix(f, "/usr/lib/rmpp-preload.d/") {
			p.Restart = true
		}
	}
	// a removed preload folder takes its links along: don't list them twice
	if owners["rmpp-preload"] {
		var fs []string
		for _, f := range p.Files {
			if !strings.HasPrefix(f, "/usr/lib/rmpp-preload.d/") {
				fs = append(fs, f)
			}
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
