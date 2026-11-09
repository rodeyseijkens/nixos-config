import QtQuick

// Where on the monitor a ScreenPopup sits. Pure data — ScreenPopup maps it
// onto the layer surface. `height` of -1 means content-driven: the window
// sizes itself to the content's implicitHeight.
QtObject {
  property bool left: false
  property bool top: false
  property bool right: false
  property bool bottom: false
  property int marginLeft: 0
  property int marginTop: 0
  property int marginRight: 0
  property int marginBottom: 0
  property int width: 0
  property int height: -1
}
