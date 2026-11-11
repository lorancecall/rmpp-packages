package main

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// The catalog is the same one the shell installers use: mods.txt lists GitHub repositories, each describes itself
// in rmpp-mod.conf (see MODS.md), and a mod's addons= URL lists sub-options (blocks separated by "---").

const (
	repoURL      = "https://lorancecall.github.io/rmpp-packages"
	vellumREADME = "https://raw.githubusercontent.com/vellum-dev/vellum-cli/main/README.md"
	bootstrapURL = "https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh"
)

// Mod is one row of the menu: a mod or one of its add-ons (Parent set).
type Mod struct {
	ID        string            `json:"id"`
	Repo      string            `json:"repo"`
	Type      string            `json:"type"`    // vellum | release
	Package   string            `json:"package"` // vellum package name
	Needs     []string          `json:"needs"`
	Assets    []string          `json:"assets"`
	Check     string            `json:"-"` // shell test on the tablet for release mods
	Default   bool              `json:"default"`
	Parent    string            `json:"parent"`
	Label     string            `json:"label"`
	Short     map[string]string `json:"short"`  // ko / en
	Detail    map[string]string `json:"detail"` // ko / en, lines separated by |
	Addons    string            `json:"-"`
	Installed bool              `json:"installed"`
}

var client = &http.Client{Timeout: 60 * time.Second}

func fetch(url string) ([]byte, error) {
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s: %s", url, resp.Status)
	}
	return io.ReadAll(resp.Body)
}

// parseConf reads key=value lines (first value of a key wins, # comments and blank lines skipped).
func parseConf(text string) map[string]string {
	kv := map[string]string{}
	sc := bufio.NewScanner(strings.NewReader(strings.ReplaceAll(text, "\r", "")))
	for sc.Scan() {
		line := sc.Text()
		t := strings.TrimSpace(line)
		if t == "" || strings.HasPrefix(t, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		if _, seen := kv[k]; !seen {
			kv[k] = v
		}
	}
	return kv
}

func modFrom(kv map[string]string, repo, parent string) Mod {
	m := Mod{
		ID: kv["id"], Repo: repo, Type: kv["type"], Package: kv["package"],
		Needs: strings.Fields(kv["needs"]), Assets: strings.Fields(kv["assets"]), Check: kv["check"],
		Default: kv["default"] == "1", Parent: parent, Label: kv["label"], Addons: kv["addons"],
		Short:  map[string]string{"ko": kv["short_ko"], "en": kv["short_en"]},
		Detail: map[string]string{"ko": kv["detail_ko"], "en": kv["detail_en"]},
	}
	if m.Type == "" {
		m.Type = "vellum"
	}
	if m.Parent == "" {
		m.Parent = kv["parent"]
	}
	return m
}

// loadCatalog returns the mods in menu order, each mod followed by its add-ons. Mods whose description cannot be
// fetched are skipped and reported in warnings.
func loadCatalog() (mods []Mod, warnings []string, err error) {
	list, err := fetch(repoURL + "/mods.txt")
	if err != nil {
		return nil, nil, err
	}
	for _, line := range strings.Split(strings.ReplaceAll(string(list), "\r", ""), "\n") {
		repo := strings.TrimSpace(strings.SplitN(line, "#", 2)[0])
		if repo == "" {
			continue
		}
		conf, err := fetch("https://raw.githubusercontent.com/" + repo + "/HEAD/rmpp-mod.conf")
		if err != nil {
			warnings = append(warnings, repo+": "+err.Error())
			continue
		}
		m := modFrom(parseConf(string(conf)), repo, "")
		if m.ID == "" {
			warnings = append(warnings, repo+": rmpp-mod.conf has no id")
			continue
		}
		mods = append(mods, m)
		if m.Addons == "" || !strings.HasPrefix(m.Addons, "http") {
			continue
		}
		text, err := fetch(m.Addons)
		if err != nil {
			warnings = append(warnings, m.ID+" add-ons: "+err.Error())
			continue
		}
		for _, block := range splitBlocks(string(text)) {
			a := modFrom(parseConf(block), repo, m.ID)
			if a.ID != "" {
				mods = append(mods, a)
			}
		}
	}
	return mods, warnings, nil
}

func splitBlocks(text string) []string {
	var blocks []string
	var cur []string
	for _, l := range strings.Split(strings.ReplaceAll(text, "\r", ""), "\n") {
		if strings.HasPrefix(l, "---") {
			blocks = append(blocks, strings.Join(cur, "\n"))
			cur = nil
			continue
		}
		cur = append(cur, l)
	}
	return append(blocks, strings.Join(cur, "\n"))
}
