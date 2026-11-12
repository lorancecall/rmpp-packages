package main

import (
	"errors"
	"fmt"
	"sort"
	"strings"
)

// UninstallOptions are the choices of "Remove everything".
type UninstallOptions struct {
	Purge  bool `json:"purge"`  // also delete the mods' settings and data (vellum purge, ~/.config/<mod>, ~/.local/share/<mod>)
	Vellum bool `json:"vellum"` // also remove Vellum itself, when no other package needs it
}

// UninstallPlan says what "Remove everything" will do; PlanUninstall shows it before anything is removed.
type UninstallPlan struct {
	Packages []string `json:"packages"` // rmpp Vellum packages (from this catalog), removed with vellum del/purge
	Files    []string `json:"files"`    // mods not installed by Vellum (GitHub release or copied by hand): their folders
	Preload  bool     `json:"preload"`  // rmpp-preload is removed too
	Vellum   bool     `json:"vellum"`   // Vellum is removed too
	Kept     []string `json:"kept"`     // other packages on the tablet: they keep rmpp-preload and Vellum
	Commands []string `json:"commands"` // the shell commands, in order
}

// Packages that come with Vellum itself or describe the device; never "other" packages.
var vellumBase = map[string]bool{"vellum": true, "vellum-bash-completion": true, "mount-utils": true,
	"remarkable-os": true, "rmpp": true}

const (
	vellumBin    = "/home/root/.vellum/bin/vellum"
	preloadDir   = "/usr/lib/rmpp-preload.d"
	restartXochi = "systemctl reset-failed xochitl 2>/dev/null; systemctl restart xochitl; sleep 3"
)

// plan works out the removal from what is on the tablet. Only packages named in this catalog (and rmpp-preload)
// are removed: packages from other repositories stay, and while any are installed rmpp-preload and Vellum stay too.
func (a *App) plan(o UninstallOptions) (UninstallPlan, error) {
	t := a.tablet
	p := UninstallPlan{}
	hasVellum := t.ok("[ -x " + vellumBin + " ]")
	installed := map[string]bool{}
	if hasVellum {
		out, err := t.run(vellumBin+" list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1", nil, nil)
		if err != nil {
			return p, fmt.Errorf("reading the installed packages: %w", err)
		}
		for _, l := range strings.Fields(out) {
			installed[pkgVersion.ReplaceAllString(l, "")] = true
		}
	}
	ours := map[string]bool{"rmpp-preload": true}
	for _, m := range a.mods {
		if m.Package != "" {
			ours[m.Package] = true
		}
	}
	for name := range installed {
		switch {
		case ours[name] && name != "rmpp-preload":
			p.Packages = append(p.Packages, name)
		case !ours[name] && !vellumBase[name]:
			p.Kept = append(p.Kept, name)
		}
	}
	sort.Strings(p.Packages)
	sort.Strings(p.Kept)

	// Mods that are not Vellum packages (GitHub release) or were copied by hand: a link in rmpp-preload.d and their
	// folder in /usr/lib, named like the mod (or its package).
	links, _ := t.run("ls "+preloadDir+" 2>/dev/null", nil, nil)
	for _, m := range a.mods {
		if m.Parent != "" {
			continue
		}
		name := m.ID
		if m.Package != "" {
			name = m.Package
		}
		if m.Type == "vellum" && installed[m.Package] {
			continue // Vellum removes its files
		}
		for _, l := range strings.Fields(links) {
			if strings.HasSuffix(l, "-"+name+".so") {
				p.Files = append(p.Files, name)
				break
			}
		}
	}
	sort.Strings(p.Files)

	p.Preload = installed["rmpp-preload"] && len(p.Kept) == 0
	p.Vellum = o.Vellum && hasVellum && len(p.Kept) == 0

	del := "del"
	if o.Purge {
		del = "purge"
	}
	if len(p.Packages) > 0 {
		p.Commands = append(p.Commands, vellumBin+" "+del+" "+strings.Join(p.Packages, " "))
	}
	if len(p.Files) > 0 {
		var c []string
		c = append(c, "mount -o remount,rw /")
		for _, n := range p.Files {
			c = append(c, fmt.Sprintf("rm -f %s/*-%s.so", preloadDir, n), "rm -rf /usr/lib/"+n)
			if o.Purge {
				c = append(c, "rm -rf /home/root/.local/share/"+n+" /home/root/.config/"+n)
			}
		}
		c = append(c, "sync", restartXochi, "mount -o remount,ro / || true")
		p.Commands = append(p.Commands, strings.Join(c, "; "))
	} else if o.Purge {
		// data of mods that were removed earlier without purge
		var dirs []string
		for _, m := range a.mods {
			if m.Parent == "" && m.ID != "" {
				dirs = append(dirs, "/home/root/.local/share/"+m.ID, "/home/root/.config/"+m.ID)
			}
		}
		if len(dirs) > 0 {
			p.Commands = append(p.Commands, "rm -rf "+strings.Join(dirs, " "))
		}
	}
	if p.Preload {
		p.Commands = append(p.Commands, vellumBin+" del rmpp-preload")
	}
	if hasVellum && (p.Preload || !installed["rmpp-preload"]) {
		// this repository's entry and signing key (kept while rmpp-preload stays: its updates come from here);
		// other repositories stay as they are
		p.Commands = append(p.Commands, fmt.Sprintf("sed -i '\\#^%s$#d' /home/root/.vellum/etc/apk/repositories; "+
			"rm -f /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub", repoURL))
	}
	if p.Vellum {
		p.Commands = append(p.Commands, "rm -rf /home/root/.vellum; sed -i '/\\.vellum\\//d' /home/root/.bashrc")
	}
	return p, nil
}

// PlanUninstall shows what "Remove everything" would do; nothing is changed.
func (a *App) PlanUninstall(o UninstallOptions) (UninstallPlan, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tablet == nil {
		return UninstallPlan{}, errors.New("not connected")
	}
	return a.plan(o)
}

// Uninstall removes all rmpp mods (and, as chosen, their data and Vellum). The plan is worked out again here, so it
// matches the tablet at this moment. The tablet's screen restarts once or more.
func (a *App) Uninstall(o UninstallOptions) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tablet == nil {
		return errors.New("not connected")
	}
	p, err := a.plan(o)
	if err != nil {
		return err
	}
	if len(p.Commands) == 0 {
		return errors.New("nothing to remove")
	}
	for i, c := range p.Commands {
		a.step("uninstalling", fmt.Sprintf("(%d/%d)", i+1, len(p.Commands)))
		a.log("$ " + c)
		if _, err := a.tablet.run(c, nil, a.log); err != nil {
			return fmt.Errorf("removal failed: %w", err)
		}
	}
	a.step("done", "")
	return nil
}
