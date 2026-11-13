pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../plugins/panels/weather/Model.js" as Model

// WeatherService owns the saved location and the current conditions shown in
// the bar. The weather panel owns its richer forecast, air-quality and radar
// requests; temporary location peeks never change this service's bar state.
Singleton {
  id: root

  property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
  property var detectedLocationState: ({ name: "", latitude: null, longitude: null })
  property string icon: ""
  property string tempC: ""
  property string tempF: ""
  property string countryName: ""
  property string unitPreference: Model.DEFAULT_SETTINGS.unit
  property bool detectingLocation: false
  property int retryDelay: 2000

  readonly property bool autoLocation:
    String(configuredLocationState.name || "") === ""
      && (configuredLocationState.latitude === null || configuredLocationState.latitude === undefined)
  readonly property var location: autoLocation && detectedLocationState ? detectedLocationState : configuredLocationState
  readonly property string locationName: String(location.name || "")
  readonly property string locationQuery: Model.wttrLocationQuery(locationName, location.latitude, location.longitude)
  readonly property bool available: icon !== "" || tempC !== ""
  readonly property bool useImperial: Model.shouldUseImperial(unitPreference, Qt.locale().name, countryName)
  readonly property string temperature: useImperial ? tempF : tempC
  readonly property string temperatureUnit: useImperial ? "°F" : "°C"

  readonly property string locationPath:
    (Quickshell.env("HOME") || "") + "/.local/state/quickshell/settings/weather.json"

  function syncSettings(): void {
    var stored = PanelSettings.entry("weather")
    unitPreference = stored && stored.unit !== undefined
      ? String(stored.unit) : Model.DEFAULT_SETTINGS.unit
  }

  Connections {
    target: PanelSettings
    function onChanged(name, values): void {
      if (name === "weather") root.syncSettings()
    }
    function onLoadedChanged(): void {
      if (PanelSettings.loaded) root.syncSettings()
    }
  }

  onConfiguredLocationStateChanged: {
    countryName = ""
    if (autoLocation) detectLocation()
    Qt.callLater(refresh)
  }
  onLocationQueryChanged: Qt.callLater(refresh)
  onAutoLocationChanged: if (autoLocation) detectLocation()

  Component.onCompleted: {
    syncSettings()
    refresh()
    refreshTimer.start()
    if (autoLocation) detectLocation()
  }

  function detectLocation(): void {
    if (locationProc.running || !autoLocation) return
    detectingLocation = true
    locationProc.running = true
  }

  function parseIpLocation(raw): var {
    try {
      var data = JSON.parse(String(raw || ""))
      var lat = parseFloat(data.latitude)
      var lon = parseFloat(data.longitude)
      if (isNaN(lat) || isNaN(lon)) return { name: "", latitude: null, longitude: null }
      return {
        name: String(data.city || data.region || data.country_name || ""),
        latitude: lat,
        longitude: lon,
        country: String(data.country_name || "")
      }
    } catch (e) {
      return { name: "", latitude: null, longitude: null }
    }
  }

  function updateCurrent(current, country): bool {
    if (!current) return false
    var c = Model.roundedTemp(current.temp_C)
    if (c === "") return false
    var f = Model.roundedTemp(current.temp_F)
    if (f === "") f = Model.roundedTemp(Model.celsiusToFahrenheit(current.temp_C))
    var nextIcon = Model.currentIcon(current, icon)
    if (nextIcon !== "") icon = nextIcon
    tempC = c
    tempF = f
    if (country) countryName = String(country)
    return true
  }

  // A failed first fetch at login retries quickly, then backs off to one
  // minute while offline. A success returns to the regular refresh interval.
  function noteFetchResult(succeeded: bool): void {
    if (succeeded) {
      retryDelay = 2000
      retryTimer.stop()
      return
    }
    retryTimer.interval = retryDelay
    retryDelay = Math.min(retryDelay * 2, 60000)
    retryTimer.restart()
  }

  function refresh(): void {
    if (autoLocation && detectedLocationState.name === "" && detectedLocationState.latitude === null)
      detectLocation()

    var lat = parseFloat(String(location.latitude))
    var lon = parseFloat(String(location.longitude))
    if (!isNaN(lat) && !isNaN(lon)) {
      openMeteoProc.command = Model.curlGet(
        "https://api.open-meteo.com/v1/forecast?latitude=" + encodeURIComponent(String(lat))
          + "&longitude=" + encodeURIComponent(String(lon))
          + "&current=temperature_2m,weather_code,is_day&timezone=auto",
        5, Model.MAX_JSON_BYTES)
      if (!openMeteoProc.running) openMeteoProc.running = true
    } else {
      wttrProc.command = Model.curlGet("https://wttr.in/" + locationQuery + "?format=j1", 8, Model.MAX_JSON_BYTES)
      if (!wttrProc.running) wttrProc.running = true
    }
  }

  function setConfiguredLocation(value): void {
    configuredLocationState = {
      name: String(value && value.name || ""),
      latitude: value ? value.latitude : null,
      longitude: value ? value.longitude : null
    }
    if (autoLocation) detectedLocationState = ({ name: "", latitude: null, longitude: null })
  }

  function reloadLocation(): void {
    locationFile.reload()
  }

  Process {
    id: locationProc
    command: Model.curlGet("https://ipapi.co/json/", 4, Model.MAX_PLACE_NAME_BYTES)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.detectingLocation = false
        var found = root.parseIpLocation(text)
        if (found.name !== "" || found.latitude !== null) {
          root.detectedLocationState = found
          if (found.country) root.countryName = found.country
          Qt.callLater(root.refresh)
        }
      }
    }
  }

  FileView {
    id: locationFile
    path: root.locationPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.configuredLocationState = Model.parseLocationFile(text())
    onLoadFailed: root.configuredLocationState = Model.parseLocationFile("")
  }

  Timer {
    interval: 1500
    running: true
    onTriggered: locationFile.reload()
  }

  Process {
    id: openMeteoProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var succeeded = false
        try {
          var parsed = JSON.parse(String(text || "").trim())
          var current = Model.openMeteoCurrentCondition({ current: parsed.current })
          succeeded = root.updateCurrent(current, root.countryName)
        } catch (e) {}
        root.noteFetchResult(succeeded)
      }
    }
  }

  Process {
    id: wttrProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var succeeded = false
        try {
          var parsed = JSON.parse(String(text || "").trim())
          var current = parsed.current_condition && parsed.current_condition[0]
          var area = parsed.nearest_area && parsed.nearest_area[0]
          var country = area && area.country && area.country[0] ? area.country[0].value : ""
          succeeded = root.updateCurrent(current, country)
        } catch (e) {}
        root.noteFetchResult(succeeded)
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 15 * 60 * 1000
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: retryTimer
    repeat: false
    onTriggered: root.refresh()
  }
}
