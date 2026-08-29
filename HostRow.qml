import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One host line: connection dot, name + OS, update/security/reboot badges.
RowLayout {
  id: root

  property var host: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property color accent: Color.accent
  property color urgent: Color.urgent

  width: parent ? parent.width : 200
  spacing: Style.space(8)

  readonly property bool online: host ? host.reporting_state === "reporting" : false
  readonly property int updates: host ? (Number(host.updates_count) || 0) : 0
  readonly property int sec: host ? (Number(host.security_updates_count) || 0) : 0
  readonly property bool reboot: host ? host.needs_reboot === true : false

  Text {
    text: "\u25CF"
    color: !root.online ? root.urgent
      : (root.reboot ? root.urgent
        : (root.updates > 0 ? root.accent : root.foreground))
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Column {
    Layout.fillWidth: true
    Text {
      text: (root.host ? (root.host.friendly_name || root.host.hostname || "") : "")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: parent.width
    }
    Text {
      text: root.host ? ((root.host.os_type || "") + (root.host.os_version ? " " + root.host.os_version : "")) : ""
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: parent.width
    }
  }

  Text {
    visible: root.updates > 0
    text: root.updates + " pkgs"
    color: root.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
  Text {
    visible: root.sec > 0
    text: root.sec + " sec"
    color: root.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
  Text {
    visible: root.reboot
    text: "\uF011"
    color: root.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
