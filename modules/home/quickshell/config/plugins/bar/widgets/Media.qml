pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "../../../"
import "../../../services"

// Media: the bar's now-playing control. The note keeps the media purple; the
// play/pause glyph beside it uses the bar foreground. No track text here: the
// panel has that. Both icons hide while nothing is playing.
Row {
  id: root
  required property var barScreen
  spacing: 6

  readonly property string screenName: root.barScreen ? (root.barScreen.name ?? "") : ""
  readonly property var players: Mpris.players && Mpris.players.values ? Mpris.players.values : []
  readonly property var player: {
    var list = root.players
    if (list.length === 0)
      return null
    if (root._pinned) {
      for (var p = 0; p < list.length; p++)
        if (list[p] === root._pinned)
          return root._pinned
    }
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].isPlaying && hasMetadata(list[i]))
        return list[i]
    for (var j = 0; j < list.length; j++)
      if (list[j] && hasMetadata(list[j]))
        return list[j]
    return list[0]
  }
  readonly property bool playing: root.player ? root.player.isPlaying : false
  readonly property bool active: root.player !== null

  property var _pinned: null

  function hasMetadata(p) {
    return !!(p && (p.trackTitle || p.trackArtist || p.trackAlbum || p.identity))
  }

  function flashOsd(glyph, label) {
    var detail = root.player && root.player.trackTitle
      ? label + " · " + root.player.trackTitle
      : label
    OsdBus.show({ kind: "media", icon: glyph, message: detail, duration: 1100 })
  }

  function togglePlayback() {
    var p = root.player
    if (!p || !p.canTogglePlaying)
      return
    var wasPlaying = p.isPlaying
    p.togglePlaying()
    root.flashOsd(wasPlaying ? "" : "", wasPlaying ? "Paused" : "Playing")
  }

  function previousTrack() {
    var p = root.player
    if (!p || !p.canGoPrevious)
      return
    p.previous()
    root.flashOsd("\uf048", "Previous")
  }

  function nextTrack() {
    var p = root.player
    if (!p || !p.canGoNext)
      return
    p.next()
    root.flashOsd("\uf051", "Next")
  }

  function togglePanel() {
    if (!root.active)
      return
    OverlayPanels.toggle("media", root.screenName)
  }

  // No player, nothing shown: the bar keeps no idle media slot. A paused
  // player stays visible, which is what the play glyph is for.
  visible: root.active && hasMetadata(root.player)

  Text {
    id: noteText
    anchors.verticalCenter: parent.verticalCenter
    text: "󰎄"
    font.family: Colors.fontFamily
    font.pixelSize: 18
    color: Colors.base0E
    opacity: noteMouse.containsMouse ? 0.6 : 1.0

    MouseArea {
      id: noteMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.togglePanel()
      onWheel: function(wheel) {
        if (wheel.angleDelta.y > 0) root.previousTrack()
        else if (wheel.angleDelta.y < 0) root.nextTrack()
      }
    }
  }

  Text {
    id: playText
    anchors.verticalCenter: parent.verticalCenter
    text: root.playing ? "" : ""
    font.family: Colors.fontFamily
    font.pixelSize: 14
    color: Colors.base05
    opacity: playMouse.containsMouse ? 0.6 : 1.0

    MouseArea {
      id: playMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.togglePlayback()
      onWheel: function(wheel) {
        if (wheel.angleDelta.y > 0) root.previousTrack()
        else if (wheel.angleDelta.y < 0) root.nextTrack()
      }
    }
  }
}
