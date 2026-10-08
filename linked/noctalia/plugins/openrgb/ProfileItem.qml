import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// ProfileItem — a single row in the saved profiles list.
// Signals: activated(), deleteRequested()
Rectangle {
  id: root

  property string profileName: ""
  property bool   isActive:    false

  readonly property bool isDeletable: profileName !== "off"

  signal activated()
  signal deleteRequested()

  radius: Style.radiusS
  color:  isActive ? Color.mSurfaceVariant : "transparent"
  border.color: isActive ? Color.mPrimary : Color.mOutline
  border.width: Style.borderS

  RowLayout {
    anchors.fill:    parent
    anchors.margins: Style.marginS

    NIcon {
      icon:      root.profileName === "off" ? "moon" : "sparkles"
      pointSize: Style.fontSizeM
      color:     root.isActive ? Color.mPrimary : Color.mOnSurfaceVariant
    }

    NText {
      text:        root.profileName
      color:       Color.mOnSurface
      font.weight: root.isActive ? Font.Bold : Font.Normal
      Layout.fillWidth: true
    }

    NIconButton {
      visible:  root.isDeletable
      icon:     "trash"
      baseSize: 26
      onClicked: root.deleteRequested()
    }
  }

  MouseArea {
    anchors.fill:          parent
    acceptedButtons:       Qt.LeftButton
    propagateComposedEvents: true
    cursorShape:           Qt.PointingHandCursor
    onClicked:             root.activated()
  }
}
