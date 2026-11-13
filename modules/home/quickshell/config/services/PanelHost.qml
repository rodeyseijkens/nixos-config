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
  property var settingsStore: ({})
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

  // Panel settings live here, not in the panels: the shared Loader destroys a
  // panel item when another one replaces it. Notification preferences share
  // this store and schema, but NotificationService owns their UI and writes.
  // Persisting this store means settings survive panel switches and restarts.
  function writeSettings() {
    settingsFile.setText(JSON.stringify(root.settingsStore, null, 2) + "\n")
  }

  function writeSettingsEntry(name, values) {
    root.settingsStore[name] = values
    root.writeSettings()
  }

  function applySettingsToCurrent() {
    var item = root.barApi.currentPanelItem
    var name = OverlayPanels.active
    if (item && name !== "" && root.settingsStore[name] !== undefined)
      item.settings = root.settingsStore[name]
  }

  function updateEntryInline(name, values) {
    root.settingsStore[name] = values
    if (root.barApi.currentPanelItem && root.barApi.currentPanelItem.moduleName === name)
      root.barApi.currentPanelItem.settings = values
    root.writeSettings()
    if (name === "notifications") NotificationService.setSettingsFromHost(values)
  }

  Connections {
    target: NotificationService
    function onPreferencesChanged(values): void {
      root.updateEntryInline("notifications", values)
    }
  }

  FileView {
    id: settingsFile
    path: (Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state"))
      + "/quickshell/panels.json"
    atomicWrites: true
    watchChanges: true
    printErrors: false

    onLoaded: {
      var parsed = null
      try {
        parsed = JSON.parse(text())
      } catch (error) {
        parsed = null
      }
      if (parsed && typeof parsed === "object") {
        root.settingsStore = parsed
        var notificationEntry = parsed.notifications
        if (notificationEntry && typeof notificationEntry === "object")
          NotificationService.setSettingsFromHost(notificationEntry)
        else {
          var defaults = NotificationService.defaultSettings
          NotificationService.setSettingsFromHost(defaults)
          if (defaults && Object.keys(defaults).length > 0)
            root.writeSettingsEntry("notifications", defaults)
        }
      } else {
        root.settingsStore = ({})
        NotificationService.setSettingsFromHost(NotificationService.defaultSettings)
      }
      root.applySettingsToCurrent()
    }
    // A first run has no file yet. Initialize the daemon entry from its
    // defaults, but don't write a file until the user changes a setting.
    onLoadFailed: {
      root.settingsStore = ({})
      NotificationService.setSettingsFromHost(NotificationService.defaultSettings)
      root.applySettingsToCurrent()
    }
    onFileChanged: reload()
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

        onLoaded: {
          if (!item)
            return;
          if (!root.settingsStore[OverlayPanels.active])
            root.settingsStore[OverlayPanels.active] = OverlayPanels.active === "weather"
              ? ({unit: "metric", timeFormat: "24", showBarTemp: true})
              : ({});
          root.barApi.currentPanelItem = item;
          root.barApi.updateEntryInlineHandler = function(name, values) {
            root.updateEntryInline(name, values);
          };
          item.bar = root.barApi;
          item.settings = root.settingsStore[OverlayPanels.active];
          item.moduleName = OverlayPanels.active;
          root.openedAt = Date.now();
          if (typeof item.open === "function")
            item.open();
        }

        Connections {
          target: OverlayPanels
          function onActiveChanged(): void {
            if (!item)
              return;
            if (OverlayPanels.active !== "")
              root.openedAt = Date.now();
            if (OverlayPanels.active === "" && typeof item.close === "function")
              item.close();
            item.bar = root.barApi;
            item.moduleName = OverlayPanels.active;
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
