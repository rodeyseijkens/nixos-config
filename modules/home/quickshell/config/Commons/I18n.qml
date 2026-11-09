pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Numbers.js" as Numbers

// Static English display strings for the ported the shell components. The
// catalog is the local shell catalog; there is no language switching, locale
// registry, or plural rules beyond English.
QtObject {
  id: root

  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

  readonly property string language: "en"
  readonly property string baseLanguage: "en"
  readonly property string formatLocale: "en-US"
  readonly property string decimal: "."
  readonly property string zeroDigit: "0"
  readonly property bool rightToLeft: false

  readonly property var strings: parseCatalog(englishFile.text())

  function t(key, fallback) {
    var value = root.strings[key]
    if (value && typeof value === "object") value = value.other
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }

  function tn(key, count, fallback) {
    var value = root.strings[key]
    if (value && typeof value === "object") {
      if (Number(count) === 1 && typeof value.one === "string") return value.one
      if (typeof value.other === "string") return value.other
    }
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }

  function formatNumber(value, decimals) {
    return Numbers.format(value, decimals, root.decimal, root.zeroDigit)
  }

  function parseCatalog(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({})
    } catch (e) {
      return ({})
    }
  }

  property FileView englishFile: FileView {
    path: root.configHome + "/quickshell/shell/Commons/shell.json"
    watchChanges: true
    printErrors: false
    blockLoading: true
    onFileChanged: reload()
  }
}
