//go:build smoke

// Read-only checks against the online catalog and a real tablet (nothing is installed):
//
//	RMPP_HOST=10.11.99.1 go test -tags smoke -run Smoke -v .
package main

import (
	"os"
	"testing"
)

func TestSmoke(t *testing.T) {
	mods, warn, err := loadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	for _, m := range mods {
		t.Logf("mod %-16s parent=%-10s type=%-7s pkg=%-16s needs=%v default=%v", m.ID, m.Parent, m.Type, m.Package, m.Needs, m.Default)
	}
	for _, w := range warn {
		t.Logf("warning: %s", w)
	}
	host := os.Getenv("RMPP_HOST")
	if host == "" {
		t.Skip("RMPP_HOST not set: tablet part skipped")
	}
	tab, auth, needPw, err := connect(host, "", ConnectOptions{KeyPath: os.Getenv("RMPP_KEY")})
	if err != nil || needPw {
		t.Fatalf("connect: needPassword=%v err=%v", needPw, err)
	}
	t.Logf("logged in with %s", auth)
	defer tab.Close()
	a := &App{tablet: tab, mods: mods}
	r, err := a.status()
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("vellum=%v needsRestore=%v model=%q installed=%v manual=%v", r.Vellum, r.NeedsRestore, r.Model, r.Installed, r.Manual)
}
