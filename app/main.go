// rmpp setup: a desktop app (Windows, macOS, Linux) that installs the rmpp mods on a reMarkable Paper Pro over SSH.
// It does what installer/install-rmpp.sh and install-rmpp.ps1 do, with a window instead of a terminal menu.
package main

import (
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	app := NewApp()
	err := wails.Run(&options.App{
		Title:            "rmpp setup",
		Width:            860,
		Height:           720,
		MinWidth:         640,
		MinHeight:        520,
		AssetServer:      &assetserver.Options{Assets: assets},
		BackgroundColour: &options.RGBA{R: 251, G: 250, B: 247, A: 1},
		OnStartup:        app.startup,
		OnShutdown:       app.shutdown,
		Bind:             []interface{}{app},
	})
	if err != nil {
		println("Error:", err.Error())
	}
}
