import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Click-to-collapse section header with a count badge.
Item {
  id: root

  property string title: ""
  property string badge: ""
  property color badgeColor: Color.foreground
  property bool defaultOpen: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool openState: defaultOpen

  default property alias content: bodyCol.data

  implicitWidth: parent ? parent.width : 200
  implicitHeight: header.height + (openState ? body.implicitHeight + Style.space(10) : 0)

  MouseArea {
    id: header
    width: parent.width
    height: headerRow.implicitHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.openState = !root.openState

    Row {
      id: headerRow
      spacing: Style.space(8)

      Text {
        text: root.openState ? "\uF078" : "\uF054"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Text {
        text: root.title.toUpperCase()
        color: Qt.darker(root.foreground, 1.3)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
      }
      Text {
        text: root.badge
        color: root.badgeColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        visible: root.badge !== ""
      }
    }
  }

  Item {
    id: body
    anchors.top: header.bottom
    anchors.topMargin: Style.space(8)
    width: parent.width
    height: openState ? bodyCol.implicitHeight : 0
    implicitHeight: height
    visible: openState

    Column {
      id: bodyCol
      width: parent.width
      spacing: Style.space(6)
    }
  }
}
