import Quickshell.Io
import Quickshell
import QtQuick
import qs.Commons
import "../plugins/notifications"

// PanelHost: one ScreenPopup that renders whichever overlay panel is active.
// Vendored panel content lives in plugins/panels/<Name>/PanelContent.qml and
// receives the BarApi instance through its `bar` property.
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
    tailscale: {file: "../plugins/panels/tailscale/PanelContent.qml", width: 390}
  })

  readonly property var current: panels[OverlayPanels.active] ?? null
  readonly property string panelFile: current ? current.file : ""
  readonly property int panelWidth: current ? current.width : 380

  function applySettingsTo(item, name): void {
    if (!item || !PanelSettings.loaded || !name) return
    item.settings = PanelSettings.ensure(name, item.defaultSettings || ({}))
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
          item.moduleName = name
          item.settings = item.defaultSettings || ({})
          root.applySettingsTo(item, name)
          root.openedAt = Date.now()
          if (typeof item.open === "function") item.open()
        }

        onLoaded: prepareItem()

        Connections {
          target: OverlayPanels
          function onActiveChanged(): void {
            if (!loader.item) return
            if (OverlayPanels.active !== "")
              root.openedAt = Date.now()
            if (OverlayPanels.active === "" && typeof loader.item.close === "function")
              loader.item.close()
            loader.item.bar = root.barApi
            loader.item.moduleName = OverlayPanels.active
            root.applySettingsTo(loader.item, OverlayPanels.active)
          }
        }

        Connections {
          target: PanelSettings
          function onChanged(name, values): void {
            if (loader.item && name === OverlayPanels.active)
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
}
