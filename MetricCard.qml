import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Small dashboard card: glyph + value + label, tinted by status.
BorderSurface {
  id: root

  property string glyph: ""
  property string label: ""
  property string value: ""
  property color tint: Color.foreground
  property string fontFamily: Style.font.family

  color: "transparent"
  borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)
  radius: Style.cornerRadius

  implicitWidth: col.implicitWidth + Style.spacing.controlPaddingX * 2
  implicitHeight: col.implicitHeight + Style.spacing.controlPaddingY * 2

  Column {
    id: col
    anchors.fill: parent
    anchors.margins: Style.spacing.controlPaddingX
    spacing: Style.space(4)

    Text {
      text: root.glyph
      color: root.tint
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
    }

    Text {
      text: root.value
      color: root.tint
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Text {
      text: root.label
      color: Qt.darker(root.tint, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.8
    }
  }
}
