package main

import (
	"reflect"
	"strings"
	"testing"
)

// What `ls -d` shows on a tablet that had every rmpp add-on and was then factory-reset (Vellum gone).
var afterReset = []string{
	"/usr/bin/rmpp-lang",
	"/usr/lib/rmpp-bt", "/usr/lib/rmpp-hwr", "/usr/lib/rmpp-lang", "/usr/lib/rmpp-preload", "/usr/lib/rmpp-preload.d",
	"/usr/lib/rmpp-refresh", "/usr/lib/rmpp-tailscale",
	"/usr/lib/rmpp-preload.d/50-rmpp-bt.so", "/usr/lib/rmpp-preload.d/50-rmpp-lang.so",
	"/usr/lib/rmpp-preload.d/50-rmpp-refresh.so", "/usr/lib/rmpp-preload.d/50-rmpp-tailscale.so",
	"/usr/lib/rmpp-preload.d/60-rmpp-hwr.so",
	"/usr/lib/systemd/system/rmpp-bluetooth.service", "/usr/lib/systemd/system/rmpp-bt-reconnect.service",
	"/usr/lib/systemd/system/rmpp-tailscale-ssh.socket", "/usr/lib/systemd/system/rmpp-tailscale-ssh@.service",
	"/usr/lib/systemd/system/rmpp-tailscaled.service",
	"/usr/lib/systemd/system/multi-user.target.wants/rmpp-bluetooth.service",
	"/usr/lib/systemd/system/multi-user.target.wants/rmpp-tailscaled.service",
	"/usr/lib/systemd/system/xochitl.service.d/zz-rmpp-preload.conf",
}

func TestLeftoverOwner(t *testing.T) {
	for p, want := range map[string]string{
		"/usr/lib/rmpp-preload.d/60-rmpp-hwr.so":                                 "rmpp-hwr",
		"/usr/lib/rmpp-preload.d/40-rmpp-remote.so":                              "rmpp-remote",
		"/usr/lib/rmpp-preload.d":                                                "rmpp-preload",
		"/usr/lib/systemd/system/xochitl.service.d/zz-rmpp-preload.conf":         "rmpp-preload",
		"/usr/lib/systemd/system/rmpp-tailscale-ssh@.service":                    "rmpp-tailscale",
		"/usr/lib/systemd/system/multi-user.target.wants/rmpp-bluetooth.service": "rmpp-bt",
		"/usr/lib/systemd/system/rmpp-bt-reconnect.service":                      "rmpp-bt",
		"/usr/bin/rmpp-lang":                                                     "rmpp-lang",
		"/usr/lib/rmpp-refresh":                                                  "rmpp-refresh",
	} {
		if got := leftoverOwner(p); got != want {
			t.Errorf("leftoverOwner(%q) = %q, want %q", p, got, want)
		}
	}
}

func TestCleanupAfterFactoryReset(t *testing.T) {
	p := planCleanup(afterReset, map[string]bool{}) // no Vellum
	wantOwners := []string{"rmpp-bt", "rmpp-hwr", "rmpp-lang", "rmpp-preload", "rmpp-refresh", "rmpp-tailscale"}
	if !reflect.DeepEqual(p.Owners, wantOwners) {
		t.Fatalf("owners = %v", p.Owners)
	}
	for _, f := range p.Files {
		if strings.HasPrefix(f, "/usr/lib/rmpp-preload.d/") {
			t.Errorf("link %s listed although its folder goes", f)
		}
	}
	if !p.Restart || len(p.Commands) != 1 {
		t.Fatalf("restart=%v commands=%v", p.Restart, p.Commands)
	}
	c := p.Commands[0]
	for _, want := range []string{"systemctl stop rmpp-bluetooth.service rmpp-bt-reconnect.service rmpp-tailscale-ssh.socket rmpp-tailscaled.service",
		"zz-rmpp-preload.conf", "/usr/lib/rmpp-preload.d", "/usr/bin/rmpp-lang", "systemctl restart xochitl", "remount,ro"} {
		if !strings.Contains(c, want) {
			t.Errorf("command lacks %q:\n%s", want, c)
		}
	}
	if strings.Index(c, "remount,rw") > strings.Index(c, "rm -rf") {
		t.Error("files removed before the root file system is writable")
	}
}

func TestCleanupKeepsInstalledPackages(t *testing.T) {
	// Vellum still there with rmpp-preload and rmpp-bt; the rest was copied by hand or lost its package.
	p := planCleanup(afterReset, map[string]bool{"rmpp-preload": true, "rmpp-bt": true})
	for _, f := range p.Files {
		if leftoverOwner(f) == "rmpp-bt" || leftoverOwner(f) == "rmpp-preload" {
			t.Errorf("would remove %s of an installed package", f)
		}
	}
	if !reflect.DeepEqual(p.Kept, []string{"rmpp-bt", "rmpp-preload"}) {
		t.Errorf("kept = %v", p.Kept)
	}
	// links of removed add-ons go one by one, rmpp-bt's link stays
	has := strings.Contains(strings.Join(p.Files, " "), "/usr/lib/rmpp-preload.d/60-rmpp-hwr.so")
	keeps := !strings.Contains(strings.Join(p.Files, " "), "50-rmpp-bt.so")
	if !has || !keeps {
		t.Errorf("preload links wrong: %v", p.Files)
	}
}

// What `ls -d` shows after a factory reset of a tablet with rmpp-preload 0.2 (everything under /usr/lib/rmpp).
var afterResetRmppDir = []string{
	"/usr/lib/rmpp/launch", "/usr/lib/rmpp/restart", "/usr/lib/rmpp/preload.d", "/usr/lib/rmpp/env.d",
	"/usr/lib/rmpp/boot.d", "/usr/lib/rmpp/units", "/usr/lib/rmpp/rmpp-bt", "/usr/lib/rmpp/rmpp-lang",
	"/usr/lib/rmpp/rmpp-hwr", "/usr/lib/rmpp/rmpp-tailscale", "/usr/lib/rmpp/rmpp-refresh",
	"/usr/lib/rmpp/preload.d/50-rmpp-bt.so", "/usr/lib/rmpp/preload.d/60-rmpp-hwr.so",
	"/usr/lib/rmpp/env.d/rmpp-bt.env", "/usr/lib/rmpp/boot.d/50-rmpp-bt", "/usr/lib/rmpp/units/rmpp-bt",
	"/usr/lib/systemd/system/xochitl.service.d/zz-rmpp-preload.conf",
}

func TestLeftoverOwnerRmppDir(t *testing.T) {
	for p, want := range map[string]string{
		"/usr/lib/rmpp/launch":                      "rmpp-preload",
		"/usr/lib/rmpp/.trash":                      "rmpp-preload",
		"/usr/lib/rmpp/rmpp-hwr":                    "rmpp-hwr",
		"/usr/lib/rmpp/preload.d/60-rmpp-hwr.so":    "rmpp-hwr",
		"/usr/lib/rmpp/preload.d/40-rmpp-remote.so": "rmpp-remote",
		"/usr/lib/rmpp/env.d/rmpp-bt.env":           "rmpp-bt",
		"/usr/lib/rmpp/boot.d/50-rmpp-tailscale":    "rmpp-tailscale",
		"/usr/lib/rmpp/units/rmpp-bt":               "rmpp-bt",
	} {
		if got := leftoverOwner(p); got != want {
			t.Errorf("leftoverOwner(%q) = %q, want %q", p, got, want)
		}
	}
}

func TestCleanupRmppDirAfterFactoryReset(t *testing.T) {
	p := planCleanup(afterResetRmppDir, map[string]bool{})
	files := strings.Join(p.Files, " ")
	if !strings.Contains(files, "/usr/lib/rmpp ") && !strings.HasSuffix(files, "/usr/lib/rmpp") {
		t.Errorf("/usr/lib/rmpp not removed as a whole: %v", p.Files)
	}
	for _, f := range p.Files {
		if strings.HasPrefix(f, "/usr/lib/rmpp/") {
			t.Errorf("%s listed although /usr/lib/rmpp goes", f)
		}
	}
	if !strings.Contains(files, "zz-rmpp-preload.conf") || !p.Restart {
		t.Errorf("drop-in or restart missing: %+v", p)
	}
}

func TestCleanupRmppDirKeepsInstalled(t *testing.T) {
	// rmpp-preload and rmpp-bt still installed: only the others' folders and links go
	p := planCleanup(afterResetRmppDir, map[string]bool{"rmpp-preload": true, "rmpp-bt": true})
	files := strings.Join(p.Files, " ")
	for _, keep := range []string{"/usr/lib/rmpp/launch", "/usr/lib/rmpp/rmpp-bt", "50-rmpp-bt.so", "rmpp-bt.env", "zz-rmpp-preload"} {
		if strings.Contains(files, keep) {
			t.Errorf("would remove %s: %v", keep, p.Files)
		}
	}
	for _, gone := range []string{"/usr/lib/rmpp/rmpp-hwr", "/usr/lib/rmpp/preload.d/60-rmpp-hwr.so", "/usr/lib/rmpp/rmpp-lang"} {
		if !strings.Contains(files, gone) {
			t.Errorf("does not remove %s: %v", gone, p.Files)
		}
	}
}

func TestCleanupNothingLeft(t *testing.T) {
	p := planCleanup(nil, nil)
	if len(p.Files) != 0 || len(p.Commands) != 0 {
		t.Errorf("plan for a clean tablet: %+v", p)
	}
}

func TestSupportedDevice(t *testing.T) {
	if err := supportedDevice("reMarkable Ferrari\n", "3.29.1.0\n"); err != nil {
		t.Errorf("Paper Pro on 3.29 refused: %v", err)
	}
	for _, c := range [][2]string{{"reMarkable 2.0", "3.29.1.0"}, {"reMarkable Chiappa", "3.29.1.0"}, {"", ""},
		{"reMarkable Ferrari", "3.30.0.1"}} {
		if supportedDevice(c[0], c[1]) == nil {
			t.Errorf("accepted %q %q", c[0], c[1])
		}
	}
}
