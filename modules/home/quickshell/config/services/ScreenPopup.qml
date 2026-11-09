pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import QtQuick

// ScreenPopup: the per-monitor popup surface. Every transient feature —
// OSD, notification panel, toast feed, calendar — appears through this module
// instead of hand-rolling a PanelWindow: it owns the per-screen fan-out, the
// layer-exclusion semantics (float over everything, reserve no space, never
// mask input regions), keyboard focus, focus-grab dismissal and Esc handling.
// The Bar deliberately does not use it: it is an always-visible dock that
// reserves space from windows.
//
// Interface:
//   placement      — a PopupPlacement (edges, margins, size)
//   showWhen       — (screenName) => bool; one idiom for every visibility
//                    guard, evaluated per screen
//   focusable      — window accepts keyboard input (needed for Esc)
//   focusGrab      — while visible, confine input to the popup; clicking
//                    outside emits dismissRequested()
//   content        — Component cloned once per screen (read singletons, never
//                    modelData; per-screen variation goes through showWhen)
//   dismissRequested() — emitted on Esc and on outside-click/grab-clear;
//                    the feature wires it to its own state in one line
Scope {
  id: root

  required property PopupPlacement placement
  property var showWhen: (name) => false
  property bool focusable: false
  property bool focusGrab: false
  property Component content
  signal dismissRequested()

  Variants {
    id: variants
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      readonly property string screenName: modelData.name ?? ""
      screen: modelData

      anchors {
        left: root.placement.left
        top: root.placement.top
        right: root.placement.right
        bottom: root.placement.bottom
      }
      margins {
        left: root.placement.marginLeft
        top: root.placement.marginTop
        right: root.placement.marginRight
        bottom: root.placement.marginBottom
      }
      implicitWidth: root.placement.width
      implicitHeight: root.placement.height >= 0 ? root.placement.height : contentLoader.implicitHeight
      exclusiveZone: 0
      exclusionMode: ExclusionMode.Ignore
      aboveWindows: true
      focusable: root.focusable
      color: "transparent"
      visible: root.showWhen(screenName)

      // Focus-grab popups show on one screen at a time, so last-writer-wins
      // on `active` is safe (same pattern the panel/calendar used pre-module).
      onVisibleChanged: {
        if (root.focusGrab)
          grab.active = visible;
      }

      // Keys must live on an Item (PanelWindow is not one — Qt warns and
      // silently drops the handler).
      FocusScope {
        anchors.fill: parent
        focus: root.focusable

        Keys.onEscapePressed: event => {
          event.accepted = true;
          root.dismissRequested();
        }

        Loader {
          id: contentLoader
          anchors.fill: parent
          sourceComponent: root.content
        }
      }
    }
  }

  HyprlandFocusGrab {
    id: grab
    windows: variants.instances
    active: false
    onCleared: root.dismissRequested()
  }
}
