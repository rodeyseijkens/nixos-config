import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../"

// swaync parity: .widget-dnd switch — square, 2px border, square knob.
//   unchecked: transparent track, base0D border + base0D knob
//   checked:   base0D track, base01 border + base01 knob
// The knob fills the inner (post-border) height and sits flush against the
// border, so the track splits into two clean blocks instead of leaving a
// clipped strip beside a mis-aligned knob.
Switch {
  id: root
  implicitWidth: 48
  implicitHeight: 24


  indicator: Rectangle {
    id: track
    readonly property int inset: 2

    x: root.leftPadding
    y: (parent.height - height) / 2
    implicitWidth: 48
    implicitHeight: 24
    color: root.checked ? Colors.base0D : Colors.base01
    border.color: root.checked ? Colors.base0D : Colors.base03
    border.width: inset

    Rectangle {
      // some padding for the knob
      width: track.height - 2 * track.inset
      height: track.height - 2 * track.inset
      y: track.inset
      x: track.inset
      color: root.checked ? Colors.base01 : Colors.base0D
    }
  }

  contentItem: Item {}
}
