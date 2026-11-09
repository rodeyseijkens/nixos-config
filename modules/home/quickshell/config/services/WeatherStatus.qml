pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../plugins/panels/weather/Model.js" as Model

QtObject {
  id: root

  property var configured: ({ name: "", latitude: null, longitude: null })
  property var detected: ({ name: "", latitude: null, longitude: null })
  property string icon: ""
  property string tempC: ""
  property string locationName: ""
  property bool detectingLocation: false

  readonly property bool autoLocation: String(configured.name || "") === "" && (configured.latitude === null || configured.latitude === undefined)
  readonly property var location: autoLocation && detected ? detected : configured
  readonly property string locationQuery: Model.wttrLocationQuery(location.name, location.latitude, location.longitude)
  readonly property bool available: icon !== "" || tempC !== ""

  onAutoLocationChanged: if (autoLocation) detectLocation()
  onConfiguredChanged: Qt.callLater(refresh)

  Component.onCompleted: {
    refresh()
    refreshTimer.start()
    if (autoLocation) detectLocation()
  }

  function detectLocation() {
    if (locationProc.running || !autoLocation) return
    detectingLocation = true
    locationProc.running = true
  }

  function refresh() {
    if (autoLocation && detected.name === "" && detected.latitude === null)
      detectLocation()
    var lat = parseFloat(String(location.latitude))
    var lon = parseFloat(String(location.longitude))
    if (!isNaN(lat) && !isNaN(lon)) {
      openMeteoProc.command = [
        "curl", "-fsS", "--max-time", "5",
        "https://api.open-meteo.com/v1/forecast?latitude=" + encodeURIComponent(String(lat))
          + "&longitude=" + encodeURIComponent(String(lon))
          + "&current=temperature_2m,weather_code,is_day&timezone=auto"
      ]
      if (!openMeteoProc.running) openMeteoProc.running = true
    } else {
      wttrProc.command = ["curl", "-fsS", "--max-time", "8", "https://wttr.in/" + locationQuery + "?format=j1"]
      if (!wttrProc.running) wttrProc.running = true
    }
  }

  function parseIpLocation(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      var lat = parseFloat(data.latitude)
      var lon = parseFloat(data.longitude)
      if (isNaN(lat) || isNaN(lon)) return { name: "", latitude: null, longitude: null }
      return {
        name: String(data.city || data.region || data.country_name || ""),
        latitude: lat,
        longitude: lon
      }
    } catch (e) {
      return { name: "", latitude: null, longitude: null }
    }
  }

  property FileView locationFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/quickshell/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.configured = Model.parseLocationFile(text())
    onLoadFailed: root.configured = Model.parseLocationFile("")
  }

  property Process locationProc: Process {
    command: ["curl", "-fsS", "--max-time", "4", "https://ipapi.co/json/"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.detectingLocation = false
        var found = root.parseIpLocation(text)
        if (found.name !== "" || found.latitude !== null) {
          root.detected = found
          root.locationName = found.name
          Qt.callLater(root.refresh)
        }
      }
    }
  }

  property Process openMeteoProc: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "").trim())
          var current = Model.openMeteoCurrentCondition(parsed)
          root.icon = Model.currentIcon(current, root.icon)
          root.tempC = Model.roundedTemp(current.temp_C)
        } catch (e) {}
      }
    }
  }

  property Process wttrProc: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "").trim())
          var current = parsed.current_condition && parsed.current_condition[0]
          root.icon = Model.currentIcon(current, root.icon)
          root.tempC = Model.roundedTemp(current.temp_C)
        } catch (e) {}
      }
    }
  }

  property Timer refreshTimer: Timer {
    interval: 15 * 60 * 1000
    repeat: true
    onTriggered: root.refresh()
  }
}
