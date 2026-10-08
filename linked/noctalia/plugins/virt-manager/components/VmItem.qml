import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property string vmId: ""
  property string vmName: ""
  property string vmState: "running"

  signal connectClicked()

  implicitHeight: 52
  radius: Style.radiusM
  color: Color.mSurfaceVariant
  border.color: Color.mOutline
  border.width: Style.borderS

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginM
    anchors.rightMargin: Style.marginM
    spacing: Style.marginM

    Rectangle {
      width: 10
      height: 10
      radius: 5
      color: root.vmState === "running" ? "#a6e3a1" : Color.mOnSurfaceVariant
    }

    NIcon {
      icon: "device-desktop"
      pointSize: Style.fontSizeM
      color: Color.mPrimary
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      NText {
        text: root.vmName
        pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mOnSurface
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      NText {
        text: root.vmState
        pointSize: Style.fontSizeS
        color: root.vmState === "running" ? "#a6e3a1" : Color.mOnSurfaceVariant
      }
    }

    NButton {
      text: "Connect"
      icon: "external-link"
      fontSize: Style.fontSizeS
      onClicked: root.connectClicked()
    }
  }
}
