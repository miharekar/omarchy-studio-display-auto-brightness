import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool settingsReady: false

  property string sensorSide: "front"
  property string profile: "balanced"
  property bool paused: false

  property bool hardwareAvailable: false
  property string monitor: ""
  property string sensorPath: ""
  property real lux: 0
  property real backLux: 0
  property real frontLux: 0
  property int brightness: 0
  property real target: 0
  property string error: "Starting"

  property bool expectedStop: false
  property bool restartPending: false
  readonly property bool controllerRunning: controller.running
  readonly property string controllerPath: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/" + (manifest?.id || "") + "/controller"

  function configEntry() {
    var config = JSON.parse(settingsFile.text())
    var sections = ["left", "center", "right"]
    var layout = config?.bar?.layout
    for (var s = 0; layout && s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++)
        if (entries[i]?.id === manifest?.id) return entries[i]
    }
    return ({})
  }

  function syncSettings() {
    if (!manifest) return
    var entry = configEntry()
    var nextSensor = ["front", "rear"].indexOf(entry.sensor) >= 0 ? entry.sensor : "front"
    var nextProfile = ["dim", "balanced", "bright"].indexOf(entry.profile) >= 0
      ? entry.profile : "balanced"
    var nextPaused = entry.paused === true
    var changed = sensorSide !== nextSensor || profile !== nextProfile
    var pauseChanged = paused !== nextPaused
    sensorSide = nextSensor
    profile = nextProfile
    paused = nextPaused
    settingsReady = true
    if (changed || pauseChanged) restartController()
    else startController()
  }

  function persist(nextSensor, nextProfile, nextPaused) {
    if (!shell || !manifest) return
    shell.updateEntryInline(manifest.id, {
      id: manifest.id,
      sensor: nextSensor,
      profile: nextProfile,
      paused: nextPaused
    })
  }

  function setSensorSide(value) {
    if (["front", "rear"].indexOf(value) < 0 || sensorSide === value) return
    persist(value, profile, paused)
  }

  function setProfile(value) {
    if (["dim", "balanced", "bright"].indexOf(value) < 0 || profile === value) return
    persist(sensorSide, value, paused)
  }

  function setPaused(value) {
    value = value === true
    if (paused === value) return
    persist(sensorSide, profile, value)
  }

  function startController() {
    if (!settingsReady || paused || controller.running || !manifest?.id) return
    expectedStop = false
    controller.command = [
      "setpriv", "--pdeathsig", "TERM",
      controllerPath,
      "--sensor", sensorSide,
      "--profile", profile
    ]
    controller.running = true
  }

  function restartController() {
    restartTimer.stop()
    if (controller.running) {
      expectedStop = true
      restartPending = !paused
      controller.running = false
    } else if (!paused) {
      startController()
    }
  }

  function applyStatus(line) {
    try {
      var status = JSON.parse(String(line))
      hardwareAvailable = status.available === true
      monitor = status.monitor || ""
      sensorPath = status.sensor || ""
      if (typeof status.lux === "number") lux = status.lux
      if (typeof status.backLux === "number") backLux = status.backLux
      if (typeof status.frontLux === "number") frontLux = status.frontLux
      if (typeof status.brightness === "number") brightness = status.brightness
      if (typeof status.target === "number") target = status.target
      error = status.error || ""
      if (status.manual === true) setPaused(true)
    } catch (e) {
      error = "Invalid controller status"
    }
  }

  Process {
    id: controller
    stdout: SplitParser { onRead: function(line) { root.applyStatus(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        var message = String(line).trim()
        if (message !== "") root.error = message
      }
    }
    onExited: function(exitCode) {
      if (root.expectedStop) {
        root.expectedStop = false
        if (root.restartPending) {
          root.restartPending = false
          root.startController()
        }
        return
      }
      if (!root.paused) {
        root.error = "Controller exited (" + exitCode + ")"
        restartTimer.restart()
      }
    }
  }

  Timer {
    id: restartTimer
    interval: 2000
    repeat: false
    onTriggered: root.startController()
  }

  FileView {
    id: settingsFile
    // The scoped barConfig snapshot can lag one edit behind shell.json.
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.syncSettings()
  }

  onManifestChanged: {
    if (settingsFile.loaded) syncSettings()
  }

  Component.onDestruction: {
    restartTimer.stop()
    expectedStop = true
    restartPending = false
    controller.running = false
  }
}
