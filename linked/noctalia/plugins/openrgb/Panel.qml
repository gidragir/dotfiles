import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

FocusScope {
  id: root

  property var pluginApi: null

  // SmartPanel integration
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth:  Math.round(340 * Style.uiScaleRatio)
  property real contentPreferredHeight: Math.round(500 * Style.uiScaleRatio)

  readonly property string screenBarPosition: Settings.getBarPositionForScreen(pluginApi?.panelOpenScreen?.name)
  readonly property string panelPosition: {
    var pos = pluginApi?.pluginSettings?.panelPosition || "follow_launcher";
    if (pos === "follow_launcher") return Settings.data.appLauncher.position;
    return pos;
  }

  readonly property bool panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
  readonly property bool panelAnchorVerticalCenter:   panelPosition === "center" || panelPosition.startsWith("center_")
  readonly property bool panelAnchorTop:    panelPosition.startsWith("top_")
  readonly property bool panelAnchorBottom: panelPosition.startsWith("bottom_")
  readonly property bool panelAnchorLeft:   panelPosition !== "center" && panelPosition.endsWith("_left")
  readonly property bool panelAnchorRight:  panelPosition !== "center" && panelPosition.endsWith("_right")

  anchors.fill: parent
  focus: true

  readonly property var main:           pluginApi?.mainInstance ?? null
  readonly property var rgbData:        main?.rgbData ?? ({ "current": "off", "brightness": 100, "profiles": ["off"] })
  readonly property string currentProfile: rgbData?.current ?? "off"
  readonly property int currentBrightness: rgbData?.brightness ?? 100

  // Quick colors come from pluginSettings so users can customise without editing QML
  readonly property var quickColors: pluginApi?.pluginSettings?.quickColors ?? [
    { "name": "Red",    "hex": "FF0000" },
    { "name": "Cyan",   "hex": "00FFFF" },
    { "name": "Purple", "hex": "B000FF" },
    { "name": "Green",  "hex": "00FF00" },
    { "name": "Orange", "hex": "FF8800" },
    { "name": "White",  "hex": "FFFFFF" }
  ]

  property string newProfileName: ""

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color:        Color.mSurface
    radius:       Style.radiusL
    border.color: Color.mOutline
    border.width: Style.borderS
    clip: true

    ColumnLayout {
      anchors.fill:    parent
      anchors.margins: Style.marginM
      spacing:         Style.marginS

      // ── Header ────────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon:      "palette"
          pointSize: Style.fontSizeL
          color:     Color.mPrimary
        }

        NText {
          text:        "RGB Lighting Control"
          pointSize:   Style.fontSizeL
          font.weight: Font.Bold
          color:       Color.mOnSurface
          Layout.fillWidth: true
        }

        NIconButton {
          icon:        "refresh"
          tooltipText: "Refresh"
          baseSize:    30
          enabled:     !(main?.busy ?? false)
          onClicked:   if (main) main.refresh()
        }
      }

      // ── Quick Off ─────────────────────────────────────────────────────────
      NButton {
        Layout.fillWidth: true
        text:            "🌑 Turn Off All RGB (Stealth)"
        backgroundColor: root.currentProfile === "off" ? Color.mPrimary : Color.mSurfaceVariant
        textColor:       root.currentProfile === "off" ? Color.mOnPrimary : Color.mOnSurface
        enabled:         !(main?.busy ?? false)
        onClicked:       if (main) main.applyProfile("off")
      }

      // ── Brightness Slider ─────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon:      "sun"
          pointSize: Style.fontSizeM
          color:     Color.mOnSurfaceVariant
        }

        NText {
          text:        "Brightness: " + root.currentBrightness + "%"
          pointSize:   Style.fontSizeS
          font.weight: Font.DemiBold
          color:       Color.mOnSurfaceVariant
          Layout.fillWidth: true
        }
      }

      NSlider {
        Layout.fillWidth: true
        from: 5
        to: 100
        stepSize: 5
        value: root.currentBrightness
        enabled: !(main?.busy ?? false) && root.currentProfile !== "off"
        onMoved: {
          if (main) main.setBrightness(value);
        }
      }

      // ── Divider ───────────────────────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        height:           1
        color:            Color.mOutline
      }

      // ── Quick Colors ──────────────────────────────────────────────────────
      NText {
        text:        "Quick Colors"
        pointSize:   Style.fontSizeS
        font.weight: Font.DemiBold
        color:       Color.mOnSurfaceVariant
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Repeater {
          model: root.quickColors

          delegate: Rectangle {
            required property var modelData

            width:  Math.round(36 * Style.uiScaleRatio)
            height: Math.round(28 * Style.uiScaleRatio)
            radius: Style.radiusS
            color:  "#" + modelData.hex
            border.color: Color.mOutline
            border.width: Style.borderS
            opacity: (main?.busy ?? false) ? 0.5 : 1.0

            MouseArea {
              anchors.fill: parent
              cursorShape:  Qt.PointingHandCursor
              enabled:      !(main?.busy ?? false)
              onClicked:    if (main) main.applyColor(modelData.hex)
            }
          }
        }
      }

      // ── Saved Profiles ────────────────────────────────────────────────────
      NText {
        text:          "Saved Profiles"
        pointSize:     Style.fontSizeS
        font.weight:   Font.DemiBold
        color:         Color.mOnSurfaceVariant
        Layout.topMargin: Style.marginS
      }

      ScrollView {
        Layout.fillWidth:   true
        Layout.fillHeight:  true
        clip: true

        ListView {
          id:      profileList
          model:   root.rgbData?.profiles ?? []
          spacing: Style.marginS

          delegate: ProfileItem {
            required property var modelData

            width:       profileList.width
            height:      Math.round(36 * Style.uiScaleRatio)
            profileName: modelData
            isActive:    modelData === root.currentProfile

            onActivated:       if (main) main.applyProfile(modelData)
            onDeleteRequested: if (main) main.deleteProfile(modelData)
          }
        }
      }

      // ── Save as New Profile ───────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Rectangle {
          Layout.fillWidth:  true
          implicitHeight:    34 * Style.uiScaleRatio
          radius:            Style.iRadiusM
          color:             Color.mSurfaceVariant
          border.color:      nameInput.activeFocus ? Color.mPrimary : Color.mOutline
          border.width:      Style.borderS

          TextInput {
            id:              nameInput
            anchors.fill:    parent
            anchors.margins: Style.marginS
            font.pointSize:  Style.fontSizeS
            color:           Color.mOnSurface
            clip:            true
            selectByMouse:   true
            text:            root.newProfileName
            onTextChanged:   root.newProfileName = text
          }
        }

        NButton {
          text:            "Save"
          backgroundColor: Color.mPrimary
          textColor:       Color.mOnPrimary
          enabled:         !(main?.busy ?? false) && nameInput.text.trim().length > 0
          onClicked: {
            if (main) {
              main.saveProfile(nameInput.text.trim());
              nameInput.text = "";
            }
          }
        }
      }
    }
  }
}
