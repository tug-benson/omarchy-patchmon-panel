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
  property int staleAfterMin: 1440

  width: parent ? parent.width : 200
  spacing: Style.space(8)

  function hAge(iso) {
    if (!iso) return Infinity
    var t = Date.parse(iso)
    if (!t || isNaN(t)) return Infinity
    return Math.max(0, (Date.now() - t) / 60000)
  }
  readonly property bool online: host ? hAge(host.last_update) <= staleAfterMin : false
  readonly property int updates: host ? (Number(host.updates_count) || 0) : 0
  readonly property int sec: host ? (Number(host.security_updates_count) || 0) : 0
  readonly property bool reboot: host ? host.needs_reboot === true : false
  readonly property string lastSeen: host ? (function () {
    var m = hAge(host.last_update)
    if (!isFinite(m)) return "never"
    if (m < 60) return Math.round(m) + "m"
    if (m < 1440) return Math.round(m / 60) + "h"
    return Math.round(m / 1440) + "d"
  })() : ""

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
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: parent.width
    }
    Text {
      text: root.host ? ((root.host.os_type || "") + (root.host.os_version ? " " + root.host.os_version : "")) : ""
      textFormat: Text.PlainText
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
  Text {
    visible: root.lastSeen !== ""
    text: root.lastSeen
    color: !root.online ? root.urgent : Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
