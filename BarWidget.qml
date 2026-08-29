import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar-widget entry point. Displays the PatchMon health glyph in the bar and
// loads Panel.qml (the floating surface) through a Loader, forwarding the
// panel lifecycle that Quickshell/Omarchy expects for bar-widget plugins.
BarWidget {
  id: root
  moduleName: "io.github.tug-benson.patchmon"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.barIcon : "\uF233"
    foreground: panelLoader.item ? panelLoader.item.statusColor : Color.foreground
    slotSize: Style.bar.iconSlot
    tooltipText: panelLoader.item ? panelLoader.item.tooltipText : "PatchMon"
    onPressed: function (b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) { if (panelLoader.item) panelLoader.item.refresh() }
      else root.toggle()
    }
  }
}
