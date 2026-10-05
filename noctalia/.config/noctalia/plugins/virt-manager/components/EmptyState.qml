import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  implicitHeight: 200

  ColumnLayout {
    anchors.centerIn: parent
    spacing: Style.marginM

    NIcon {
      icon: "device-desktop-off"
      pointSize: Style.fontSizeXXL
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignHCenter
    }

    NText {
      text: "No running virtual machines"
      pointSize: Style.fontSizeM
      font.weight: Font.Medium
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignHCenter
    }

    NText {
      text: "Start a VM using virt-manager or virsh"
      pointSize: Style.fontSizeS
      color: Color.mOutline
      Layout.alignment: Qt.AlignHCenter
    }
  }
}
