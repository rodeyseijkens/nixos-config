pragma Singleton
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.UPower

QtObject {
  readonly property var bluetooth: Bluetooth
  readonly property var upower: UPower
  readonly property bool bluetoothAvailable: !!(bluetooth && bluetooth.defaultAdapter)
  readonly property bool batteryAvailable: !!(upower && upower.displayDevice && upower.displayDevice.isPresent)
}
