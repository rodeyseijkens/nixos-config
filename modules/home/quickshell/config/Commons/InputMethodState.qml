pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root
  property var state: ({})

  function cycle(back) {
    return false
  }
}
