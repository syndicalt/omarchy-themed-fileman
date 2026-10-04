import QtQuick
import Quickshell
import Quickshell.Io

// Reskins libadwaita apps (GTK Files among them) to match the current
// Omarchy shell theme. Visual only — no functionality changes anywhere.
//
// On startup and on every theme change this service runs
// bin/themed-files-apply --restart-nautilus, which:
//   1. reads the Omarchy palette from the current theme's colors.toml
//   2. writes ~/.config/gtk-4.0/gtk.css overriding libadwaita named colors
//   3. restarts nautilus if it is running (dbus re-activates it on demand)
//
// Theme detection: omarchy-theme-set swaps the whole current/theme directory
// (rm -rf + mv), which can defeat inode-based file watches, so detection is
// layered: FileView watchChanges on the theme files, a Connections hook on
// the shell's Color singleton (which the shell updates over IPC on theme
// switches), and a low-frequency poll of theme.name as a final backstop.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string themePath: home + "/.local/state/omarchy/current/theme"
  readonly property string themeNamePath: home + "/.local/state/omarchy/current/theme.name"
  readonly property string scriptPath: Qt.resolvedUrl("bin/themed-files-apply").toString().replace(/^file:\/\//, "")
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "cheapseatsecon.themed-files"

  property string lastThemeName: ""
  property bool started: false

  // One-shot deferred so a shell restart doesn't race nautilus startup.
  Timer {
    id: startupTimer
    interval: 3000
    repeat: false
    onTriggered: root.apply("startup")
  }

  // Coalesces rapid theme swaps into one apply per settle.
  Timer {
    id: applyDebounce
    interval: 700
    repeat: false
    onTriggered: root.apply("theme-change")
  }

  // Backstop poll: catches directory swaps that inotify missed. Cheap — one
  // stat-class file read every 10 seconds, no subprocess.
  Timer {
    id: pollTimer
    interval: 10000
    repeat: true
    onTriggered: root.checkThemeName()
  }

  FileView {
    id: themeNameFile
    path: root.themeNamePath
    watchChanges: true
    printErrors: false
    onFileChanged: applyDebounce.restart()
  }

  FileView {
    id: colorsFile
    path: root.themePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: applyDebounce.restart()
  }

  Process {
    id: applyProc
    stderr: StdioCollector {
      id: applyStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.warn("omarchy-themed-files: apply failed (" + exitCode + "): " + String(applyStderr.text || "").trim())
      }
    }
  }

  function apply(reason) {
    if (applyProc.running) return
    console.log("omarchy-themed-files: applying theme css (" + reason + ")")
    applyProc.command = [root.scriptPath, "--restart-nautilus"]
    applyProc.running = true
  }

  function checkThemeName() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", "file://" + root.themeNamePath)
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      var name = String(xhr.responseText || "").trim()
      if (name !== "" && root.lastThemeName !== "") {
        if (name !== root.lastThemeName) {
          root.lastThemeName = name
          applyDebounce.restart()
        }
        return
      }
      if (name !== "") root.lastThemeName = name
    }
    xhr.send()
  }

  // The shell pushes the new palette over IPC on runtime theme switches;
  // these properties change on every theme swap.
  Connections {
    target: Color
    function onAccentChanged() { applyDebounce.restart() }
    function onBackgroundChanged() { applyDebounce.restart() }
    function onForegroundChanged() { applyDebounce.restart() }
  }

  Component.onCompleted: {
    checkThemeName()
    startupTimer.restart()
    pollTimer.restart()
    started = true
  }
}
