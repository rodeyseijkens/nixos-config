import Quickshell.Io
import Quickshell
import QtQuick
import qs.Commons
import "../plugins/notifications"
import "../plugins/panels/calendar"

// PanelHost: one ScreenPopup that renders whichever overlay panel is active.
// Panel content lives under plugins/panels (or plugins/notifications) and
// receives the BarApi instance through its `bar` property; switching panels
// changes that one popup instead of opening a separate window.
Scope {
  id: root

  readonly property var barApi: BarApi {}
  property double openedAt: 0

  readonly property var panels: ({
    elsewhen: {file: "../plugins/panels/elsewhen/PanelContent.qml", width: 430},
    notifications: {file: "../plugins/notifications/PanelContent.qml", width: 380},
    audio: {file: "../plugins/panels/audio/PanelContent.qml", width: 390},
    bluetooth: {file: "../plugins/panels/bluetooth/PanelContent.qml", width: 390},
    network: {file: "../plugins/panels/network/PanelContent.qml", width: 400},
    power: {file: "../plugins/panels/power/PanelContent.qml", width: 350},
    media: {file: "../plugins/panels/media/PanelContent.qml", width: 400},
    weather: {file: "../plugins/panels/weather/PanelContent.qml", width: 540},
    tailscale: {file: "../plugins/panels/tailscale/PanelContent.qml", width: 390},
    // The calendar keeps its old settings entry, and sizes itself to its
    // columns because the agenda can sit beside or below the month.
    calendar: {
      file: "../plugins/panels/calendar/CalendarPanel.qml",
      width: 815,
      settingsName: "shell-calendar",
      measureWidth: true
    }
  })

  readonly property var current: panels[OverlayPanels.active] ?? null
  readonly property string panelFile: current ? current.file : ""
  property real measuredPanelWidth: 0
  readonly property int panelWidth: current
    ? (current.measureWidth === true && measuredPanelWidth > 0
      ? Math.max(320, Math.round(measuredPanelWidth))
      : current.width)
    : 380

  // Some panels keep their historical settings key, so panel names and
  // stored entries do not have to match.
  function settingsEntryName(name: string): string {
    var panel = root.panels[name]
    return panel && panel.settingsName ? panel.settingsName : name
  }

  function applySettingsTo(item, name): void {
    if (!item || !PanelSettings.loaded || !name) return
    item.settings = PanelSettings.ensure(root.settingsEntryName(name), item.defaultSettings || ({}))
  }

  function syncMeasuredWidth(item): void {
    if (!item || !root.current || root.current.measureWidth !== true) return
    if (item.implicitWidth > 0) root.measuredPanelWidth = item.implicitWidth
  }

  function syncNotificationSettings(): void {
    if (!PanelSettings.loaded) return
    var values = PanelSettings.entry("notifications")
    NotificationService.setSettingsFromHost(
      values === undefined ? NotificationService.defaultSettings : values)
  }

  Component.onCompleted: {
    NotificationService.setSettingsFromHost(NotificationService.defaultSettings)
    syncNotificationSettings()
  }

  // The notification daemon remains the owner of its settings schema. The
  // generic store only persists its entry; this host is the small adapter
  // between the daemon and panels.json.
  Connections {
    target: NotificationService
    function onPreferencesChanged(values): void {
      PanelSettings.write("notifications", values)
    }
  }

  Connections {
    target: PanelSettings
    function onChanged(name, values): void {
      if (name === "notifications") NotificationService.setSettingsFromHost(values)
    }
    function onLoadedChanged(): void {
      if (PanelSettings.loaded) root.syncNotificationSettings()
    }
  }

  ScreenPopup {
    placement: PopupPlacement {
      bottom: true
      // The bar reserves its own 28px, so this is the gap above it: the same
      // 16px the popup keeps at the screen sides.
      marginBottom: 16
      width: root.panelWidth
    }
    anchorX: OverlayPanels.anchorX
    showWhen: name => OverlayPanels.active !== "" && OverlayPanels.screenName === name
    focusable: true
    focusGrab: true
    onDismissRequested: {
      if (Date.now() - root.openedAt > 250)
        OverlayPanels.close();
    }

    content: Component {
      Loader {
        id: loader
        anchors.fill: parent
        source: root.panelFile

        function prepareItem() {
          if (!item) return
          var name = OverlayPanels.active
          item.bar = root.barApi
          item.moduleName = root.settingsEntryName(name)
          item.settings = item.defaultSettings || ({})
          root.applySettingsTo(item, name)
          root.syncMeasuredWidth(item)
          root.openedAt = Date.now()
          if (typeof item.open === "function") item.open()
        }

        onLoaded: prepareItem()

        Connections {
          target: loader.item
          function onImplicitWidthChanged(): void {
            root.syncMeasuredWidth(loader.item)
          }
        }

        Connections {
          target: OverlayPanels
          function onActiveChanged(): void {
            if (!loader.item) return
            if (OverlayPanels.active !== "")
              root.openedAt = Date.now()
            if (OverlayPanels.active === "" && typeof loader.item.close === "function")
              loader.item.close()
            loader.item.bar = root.barApi
            loader.item.moduleName = root.settingsEntryName(OverlayPanels.active)
            root.applySettingsTo(loader.item, OverlayPanels.active)
            root.syncMeasuredWidth(loader.item)
          }
        }

        Connections {
          target: PanelSettings
          function onChanged(name, values): void {
            if (loader.item && name === root.settingsEntryName(OverlayPanels.active))
              loader.item.settings = values
          }
          function onLoadedChanged(): void {
            if (PanelSettings.loaded)
              root.applySettingsTo(loader.item, OverlayPanels.active)
          }
        }
      }
    }
  }

  IpcHandler {
    target: "panel"

    function toggle(name: string): void {
      OverlayPanels.toggle(name);
    }

    // Anchor the panel over a given screen x. Bar widgets pass their own
    // centre; this is for keybinds and scripts that know where it belongs.
    function toggleAt(name: string, anchorX: real): void {
      OverlayPanels.toggle(name, "", anchorX);
    }

    function close(): void {
      OverlayPanels.close();
    }
  }

  // The calendar had its own IPC target before joining the shared popup.
  IpcHandler {
    target: "calendar"

    function toggle(): void {
      OverlayPanels.toggle("calendar");
    }

    function toggleOn(screen: string): void {
      OverlayPanels.toggle("calendar", screen);
    }
  }
}
