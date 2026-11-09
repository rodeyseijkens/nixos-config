pragma Singleton
import QtQuick
import Quickshell.Networking

QtObject {
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property bool ethernetConnected: !!(wiredDevice && wiredDevice.connected)
  readonly property bool available: !!wiredDevice || !!wifiDevice
  readonly property string icon: {
    if (ethernetConnected) return ""
    if (wifiDevice) return "\uf1eb"
    return wiredDevice ? "" : ""
  }

  function findDevice(type) {
    var devices = networkDevices || []
    var fallback = null
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device || device.type !== type) continue
      if (device.connected) return device
      if (!fallback) fallback = device
    }
    return fallback
  }
}
