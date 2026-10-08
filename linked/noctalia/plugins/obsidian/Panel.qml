import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

FocusScope {
  id: root

  property var pluginApi: null

  // Current view: "tasks" | "tags" | "search"
  property string currentView: "tasks"
  property string tagFilterText: ""

  // SmartPanel integration
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: Math.round(390 * Style.uiScaleRatio)
  property real contentPreferredHeight: Math.round(490 * Style.uiScaleRatio)

  // Position handling
  readonly property string screenBarPosition: Settings.getBarPositionForScreen(pluginApi?.panelOpenScreen?.name)
  readonly property string configuredPosition: {
    var pos = pluginApi?.pluginSettings?.panelPosition
      || pluginApi?.manifest?.metadata?.defaultSettings?.panelPosition
      || "follow_launcher";
    if (pos === "follow_launcher")
      return Settings.data.appLauncher.position;
    return pos;
  }

  readonly property string panelPosition: {
    var pos = configuredPosition;
    if (pos === "follow_bar") {
      if (screenBarPosition === "left" || screenBarPosition === "right")
        return "center_" + screenBarPosition;
      return screenBarPosition + "_center";
    }
    return pos;
  }

  readonly property bool panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
  readonly property bool panelAnchorVerticalCenter: panelPosition === "center" || panelPosition.startsWith("center_")
  readonly property bool panelAnchorTop: panelPosition.startsWith("top_")
  readonly property bool panelAnchorBottom: panelPosition.startsWith("bottom_")
  readonly property bool panelAnchorLeft: panelPosition !== "center" && panelPosition.endsWith("_left")
  readonly property bool panelAnchorRight: panelPosition !== "center" && panelPosition.endsWith("_right")

  anchors.fill: parent
  focus: true

  readonly property var main: pluginApi?.mainInstance ?? null
  readonly property var statusData: main?.statusData ?? ({
    "vault": "/data/obsidian",
    "vaultExists": true,
    "dailyFile": "",
    "dailyFilename": "",
    "exists": false,
    "todayFormatted": "",
    "totalTasks": 0,
    "completedTasks": 0,
    "pendingTasks": 0,
    "tasks": [],
    "syncStatus": "idle",
    "syncMessage": "Idle"
  })

  readonly property int totalTasks: statusData.totalTasks || 0
  readonly property int completedTasks: statusData.completedTasks || 0
  readonly property int pendingTasks: statusData.pendingTasks || 0
  readonly property string syncStatus: statusData.syncStatus || "idle"

  // Filtered tags for tags view
  readonly property var filteredTags: {
    var list = main?.tagsData || [];
    var q = tagFilterText.trim().toLowerCase();
    if (!q) return list;
    return list.filter(function(item) {
      return item.tag.toLowerCase().indexOf(q) !== -1;
    });
  }

  function closePanel() {
    if (pluginApi) {
      pluginApi.withCurrentScreen(function(screen) {
        pluginApi.closePanel(screen);
      });
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mOutline
    border.width: Style.borderS
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      // ─────────────────────────────────────────────────────────────
      // ── 1. Header (Dynamic depending on view) ──
      // ─────────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        // View icon or Back button
        NIconButton {
          visible: root.currentView !== "tasks"
          icon: "chevron-left"
          tooltipText: root.currentView === "tags" && main?.selectedTag ? "Back to Tags" : "Back to Tasks"
          baseSize: 30
          customRadius: Style.iRadiusS
          colorBg: Color.mSurfaceVariant
          colorFg: Color.mPrimary
          colorBorder: Style.boxBorderColor
          onClicked: {
            if (root.currentView === "tags" && main?.selectedTag) {
              main.selectedTag = "";
            } else {
              root.currentView = "tasks";
            }
          }
        }

        NIcon {
          visible: root.currentView === "tasks"
          icon: "notebook"
          pointSize: Style.fontSizeXL
          color: Color.mPrimary
        }

        // Title Column
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          RowLayout {
            spacing: Style.marginXS
            Text {
              text: {
                if (root.currentView === "tasks") return "Obsidian";
                if (root.currentView === "tags") {
                  return main?.selectedTag ? "#" + main.selectedTag : "Vault Tags";
                }
                return "Search Notes";
              }
              font.pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              elide: Text.ElideRight
              Layout.maximumWidth: 220 * Style.uiScaleRatio
            }

            Text {
              visible: root.currentView === "tasks"
              text: "· " + (statusData.todayFormatted || "")
              font.pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }

          Text {
            text: {
              if (root.currentView === "tasks") {
                return totalTasks > 0
                  ? (pluginApi?.tr("panel.tasksProgress", { completed: completedTasks, total: totalTasks }) || (completedTasks + "/" + totalTasks + " done"))
                  : (pluginApi?.tr("bar.noTasks") || "No tasks today");
              }
              if (root.currentView === "tags") {
                if (main?.selectedTag) {
                  return (main?.notesForTag?.length || 0) + " matching notes";
                }
                return (main?.tagsData?.length || 0) + " tags available";
              }
              return (main?.searchResults?.length || 0) + " results found";
            }
            font.pointSize: Style.fontSizeXXS
            color: (root.currentView === "tasks" && pendingTasks > 0) ? Color.mPrimary : Color.mOnSurfaceVariant
          }
        }

        // View Tabs / Dmenu trigger
        NIconButton {
          visible: root.currentView === "search" || root.currentView === "tags"
          icon: "external-link"
          tooltipText: root.currentView === "tags" ? "Open in Dmenu" : "Open in Dmenu Search"
          baseSize: 30
          customRadius: Style.iRadiusS
          colorBg: "transparent"
          colorFg: Color.mOnSurfaceVariant
          onClicked: {
            if (root.currentView === "tags") {
              main?.exploreTags();
            } else {
              main?.searchNotes();
            }
          }
        }

        // Sync Button (Tasks view)
        NIconButton {
          visible: root.currentView === "tasks"
          icon: syncStatus === "syncing" ? "refresh" : (syncStatus === "error" ? "alert-circle" : "cloud-check")
          tooltipText: syncStatus === "syncing" ? "Syncing..." : (syncStatus === "error" ? "Sync Error — Click to retry" : "Vault Synced — Click to sync")
          baseSize: 30
          customRadius: Style.iRadiusS
          colorBg: "transparent"
          colorFg: syncStatus === "error" ? Color.mError : (syncStatus === "syncing" ? Color.mPrimary : Color.mOnSurfaceVariant)
          onClicked: main?.syncVault()
        }

        // Close Button
        NIconButton {
          icon: "x"
          baseSize: 30
          customRadius: Style.iRadiusS
          colorBg: "transparent"
          colorFg: Color.mOnSurfaceVariant
          onClicked: root.closePanel()
        }
      }

      // ─────────────────────────────────────────────────────────────
      // ── 2. Unified Quick Action & View Bar ──
      // ─────────────────────────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36 * Style.uiScaleRatio
        radius: Style.iRadiusM
        color: Color.mSurfaceVariant
        border.color: Style.boxBorderColor
        border.width: Style.borderS

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.marginXS
          anchors.rightMargin: Style.marginXS
          spacing: 2

          // Tab: Tasks
          NIconButton {
            Layout.fillWidth: true
            icon: "checklist"
            tooltipText: "Daily Tasks & Notes"
            baseSize: 30
            customRadius: Style.iRadiusS
            colorBg: root.currentView === "tasks" ? Color.mPrimary : "transparent"
            colorFg: root.currentView === "tasks" ? Color.mOnPrimary : Color.mOnSurfaceVariant
            colorBorder: "transparent"
            onClicked: root.currentView = "tasks"
          }

          // Tab: Tags
          NIconButton {
            Layout.fillWidth: true
            icon: "tag"
            tooltipText: "Explore Vault Tags"
            baseSize: 30
            customRadius: Style.iRadiusS
            colorBg: root.currentView === "tags" ? Color.mPrimary : "transparent"
            colorFg: root.currentView === "tags" ? Color.mOnPrimary : Color.mOnSurfaceVariant
            colorBorder: "transparent"
            onClicked: {
              root.currentView = "tags";
              main?.fetchTags();
            }
          }

          // Tab: Search
          NIconButton {
            Layout.fillWidth: true
            icon: "search"
            tooltipText: "Search Vault Notes (AI + Ripgrep)"
            baseSize: 30
            customRadius: Style.iRadiusS
            colorBg: root.currentView === "search" ? Color.mPrimary : "transparent"
            colorFg: root.currentView === "search" ? Color.mOnPrimary : Color.mOnSurfaceVariant
            colorBorder: "transparent"
            onClicked: {
              root.currentView = "search";
              if (!main?.searchResults || main?.searchResults.length === 0) {
                main?.executeSearch("");
              }
            }
          }

          Rectangle {
            implicitWidth: 1
            implicitHeight: 20
            color: Style.boxBorderColor
          }

          // Action: New Note
          NIconButton {
            Layout.fillWidth: true
            icon: "file-plus"
            tooltipText: "New Note (Sticky / Workstation / Fleeting)"
            baseSize: 30
            colorBg: "transparent"
            colorFg: Color.mPrimary
            onClicked: main?.createNote()
          }

          // Action: Open in Neovim
          NIconButton {
            Layout.fillWidth: true
            icon: "terminal"
            tooltipText: "Open Today's Note in Neovim"
            baseSize: 30
            colorBg: "transparent"
            colorFg: Color.mOnSurface
            onClicked: main?.openDaily("neovim")
          }

          // Action: Open in Obsidian GUI
          NIconButton {
            Layout.fillWidth: true
            icon: "external-link"
            tooltipText: "Open in Obsidian Desktop"
            baseSize: 30
            colorBg: "transparent"
            colorFg: Color.mOnSurface
            onClicked: main?.openDaily("obsidian")
          }
        }
      }

      // ─────────────────────────────────────────────────────────────
      // ── VIEW A: TASKS (DEFAULT VIEW) ──
      // ─────────────────────────────────────────────────────────────
      ColumnLayout {
        visible: root.currentView === "tasks"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginS

        // Quick-Capture Bar
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 34 * Style.uiScaleRatio
          radius: Style.iRadiusM
          color: Color.mSurfaceVariant
          border.color: captureInput.activeFocus ? Color.mPrimary : Style.boxBorderColor
          border.width: Style.borderS

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginS
            anchors.rightMargin: Style.marginXS
            spacing: Style.marginXS

            TextInput {
              id: captureInput
              Layout.fillWidth: true
              font.pointSize: Style.fontSizeS
              color: Color.mOnSurface
              clip: true
              selectByMouse: true
              onAccepted: {
                if (text.trim()) {
                  main?.capture(text, "task");
                  text = "";
                }
              }

              Text {
                text: "Quick capture..."
                visible: !captureInput.text && !captureInput.activeFocus
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                opacity: 0.6
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            // + Task Button
            Rectangle {
              implicitHeight: 24
              implicitWidth: btnTaskText.implicitWidth + 12
              radius: Style.iRadiusS
              color: btnTaskHover.hovered ? Color.mHover : Color.mPrimary
              border.color: btnTaskHover.hovered ? Color.mOutline : "transparent"
              border.width: Style.borderS

              HoverHandler { id: btnTaskHover }
              TapHandler {
                onTapped: {
                  if (captureInput.text.trim()) {
                    main?.capture(captureInput.text, "task");
                    captureInput.text = "";
                  }
                }
              }

              Text {
                id: btnTaskText
                anchors.centerIn: parent
                text: "+ Task"
                font.pointSize: Style.fontSizeXXS
                font.weight: Style.fontWeightBold
                color: btnTaskHover.hovered ? Color.mOnHover : Color.mOnPrimary
              }
            }

            // Note Button
            Rectangle {
              implicitHeight: 24
              implicitWidth: btnNoteText.implicitWidth + 12
              radius: Style.iRadiusS
              color: btnNoteHover.hovered ? Color.mHover : Color.mSurface
              border.color: Color.mOutline
              border.width: Style.borderS

              HoverHandler { id: btnNoteHover }
              TapHandler {
                onTapped: {
                  if (captureInput.text.trim()) {
                    main?.capture(captureInput.text, "note");
                    captureInput.text = "";
                  }
                }
              }

              Text {
                id: btnNoteText
                anchors.centerIn: parent
                text: "Note"
                font.pointSize: Style.fontSizeXXS
                color: btnNoteHover.hovered ? Color.mOnHover : Color.mOnSurface
              }
            }
          }
        }

        // Tasks List
        ListView {
          id: taskListView
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: Style.marginXS
          model: statusData.tasks || []

          delegate: Rectangle {
            width: taskListView.width
            implicitHeight: Math.round(32 * Style.uiScaleRatio)
            radius: Style.iRadiusS
            color: taskHover.hovered ? Color.mSurfaceVariant : "transparent"
            border.color: taskHover.hovered ? Style.boxBorderColor : "transparent"
            border.width: Style.borderS

            HoverHandler { id: taskHover }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginXS
              anchors.rightMargin: Style.marginXS
              spacing: Style.marginS

              // Checkbox button
              Rectangle {
                implicitWidth: 18
                implicitHeight: 18
                radius: 4
                color: modelData.done ? Color.mPrimary : "transparent"
                border.color: modelData.done ? Color.mPrimary : Color.mOutline
                border.width: 1.5

                NIcon {
                  visible: modelData.done
                  anchors.centerIn: parent
                  icon: "check"
                  pointSize: 11
                  color: Color.mSurface
                }

                TapHandler {
                  onTapped: main?.toggleTask(modelData.line)
                }
              }

              // Task text
              Text {
                Layout.fillWidth: true
                text: modelData.text || ""
                font.pointSize: Style.fontSizeS
                font.strikeout: modelData.done
                color: modelData.done ? Color.mOnSurfaceVariant : Color.mOnSurface
                opacity: modelData.done ? 0.6 : 1.0
                elide: Text.ElideRight

                TapHandler {
                  onTapped: main?.toggleTask(modelData.line)
                }
              }
            }
          }

          // Empty state
          Item {
            anchors.fill: parent
            visible: (!statusData.tasks || statusData.tasks.length === 0)

            ColumnLayout {
              anchors.centerIn: parent
              spacing: Style.marginXS

              NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "circle-check"
                pointSize: Style.fontSizeXXL
                color: Color.mPrimary
                opacity: 0.5
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "All caught up!"
                font.pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No pending tasks today"
                font.pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }
            }
          }
        }
      }

      // ─────────────────────────────────────────────────────────────
      // ── VIEW B: TAGS EXPLORER ──
      // ─────────────────────────────────────────────────────────────
      ColumnLayout {
        visible: root.currentView === "tags"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginS

        // If no tag is selected: Show Tag search input & Tag List
        ColumnLayout {
          visible: !main?.selectedTag
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.marginS

          // Filter tags input
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32 * Style.uiScaleRatio
            radius: Style.iRadiusM
            color: Color.mSurfaceVariant
            border.color: tagInput.activeFocus ? Color.mPrimary : Style.boxBorderColor
            border.width: Style.borderS

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginS
              anchors.rightMargin: Style.marginS
              spacing: Style.marginXS

              NIcon {
                icon: "filter"
                pointSize: Style.fontSizeXS
                color: tagInput.text ? Color.mPrimary : Color.mOnSurfaceVariant
              }

              TextInput {
                id: tagInput
                Layout.fillWidth: true
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurface
                clip: true
                selectByMouse: true
                onTextChanged: root.tagFilterText = text

                Text {
                  text: "Filter tags..."
                  visible: !tagInput.text && !tagInput.activeFocus
                  font.pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                  opacity: 0.6
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              NIconButton {
                visible: tagInput.text.length > 0
                icon: "x"
                baseSize: 22
                colorBg: "transparent"
                colorFg: Color.mOnSurfaceVariant
                onClicked: tagInput.text = ""
              }
            }
          }

          // Tags list
          ListView {
            id: tagsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.filteredTags

            delegate: Rectangle {
              width: tagsListView.width
              implicitHeight: Math.round(30 * Style.uiScaleRatio)
              radius: Style.iRadiusS
              color: tagRowHover.hovered ? Color.mSurfaceVariant : "transparent"
              border.color: tagRowHover.hovered ? Style.boxBorderColor : "transparent"
              border.width: Style.borderS

              HoverHandler { id: tagRowHover }
              TapHandler {
                onTapped: main?.fetchNotesByTag(modelData.tag)
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginS
                spacing: Style.marginS

                NIcon {
                  icon: "tag"
                  pointSize: 12
                  color: tagRowHover.hovered ? Color.mPrimary : Color.mOnSurfaceVariant
                }

                Text {
                  Layout.fillWidth: true
                  text: "#" + modelData.tag
                  font.pointSize: Style.fontSizeS
                  color: tagRowHover.hovered ? Color.mPrimary : Color.mOnSurface
                  elide: Text.ElideRight
                }

                Rectangle {
                  implicitHeight: 18
                  implicitWidth: countBadgeText.implicitWidth + 10
                  radius: 9
                  color: tagRowHover.hovered ? Color.mPrimary : Color.mSurfaceVariant
                  border.color: tagRowHover.hovered ? "transparent" : Color.mOutline
                  border.width: Style.borderS
                  Text {
                    id: countBadgeText
                    anchors.centerIn: parent
                    text: String(modelData.count)
                    font.pointSize: Style.fontSizeXXS
                    font.weight: Style.fontWeightBold
                    color: tagRowHover.hovered ? Color.mOnPrimary : Color.mPrimary
                  }
                }
              }
            }

            Item {
              anchors.fill: parent
              visible: main?.isLoadingTags
              Text {
                anchors.centerIn: parent
                text: "Loading tags..."
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
              }
            }
          }
        }

        // If a tag is selected: Show matching notes
        ColumnLayout {
          visible: !!main?.selectedTag
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.marginS

          ListView {
            id: tagNotesList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.marginXS
            model: main?.notesForTag || []

            delegate: Rectangle {
              width: tagNotesList.width
              implicitHeight: Math.round(44 * Style.uiScaleRatio)
              radius: Style.iRadiusS
              color: noteRowHover.hovered ? Color.mSurfaceVariant : "transparent"
              border.color: noteRowHover.hovered ? Style.boxBorderColor : "transparent"
              border.width: Style.borderS

              HoverHandler { id: noteRowHover }
              TapHandler {
                onTapped: main?.openNote(modelData.fullPath, "neovim")
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginXS
                spacing: Style.marginS

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    text: modelData.title || ""
                    font.pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightBold
                    color: noteRowHover.hovered ? Color.mPrimary : Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: modelData.relPath || ""
                    font.pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                NIconButton {
                  icon: "external-link"
                  tooltipText: "Open in Obsidian"
                  baseSize: 26
                  colorBg: "transparent"
                  colorFg: Color.mOnSurfaceVariant
                  onClicked: main?.openNote(modelData.fullPath, "obsidian")
                }
              }
            }

            Item {
              anchors.fill: parent
              visible: main?.isLoadingTagNotes
              Text {
                anchors.centerIn: parent
                text: "Loading notes..."
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
              }
            }
          }
        }
      }

      // ─────────────────────────────────────────────────────────────
      // ── VIEW C: SEARCH NOTES (AI & FAST RIPGREP) ──
      // ─────────────────────────────────────────────────────────────
      ColumnLayout {
        visible: root.currentView === "search"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginS

        // Search Input Field
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 34 * Style.uiScaleRatio
          radius: Style.iRadiusM
          color: Color.mSurfaceVariant
          border.color: searchTextInput.activeFocus ? Color.mPrimary : Style.boxBorderColor
          border.width: Style.borderS

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginS
            anchors.rightMargin: Style.marginXS
            spacing: Style.marginXS

            NIcon {
              icon: "search"
              pointSize: Style.fontSizeS
              color: searchTextInput.text ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            TextInput {
              id: searchTextInput
              Layout.fillWidth: true
              font.pointSize: Style.fontSizeS
              color: Color.mOnSurface
              clip: true
              selectByMouse: true
              onTextChanged: searchDebounce.restart()
              onAccepted: {
                if (text.trim()) main?.executeSearch(text.trim());
              }

              Text {
                text: "Search notes (AI or text)..."
                visible: !searchTextInput.text && !searchTextInput.activeFocus
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                opacity: 0.6
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            NIconButton {
              visible: searchTextInput.text.length > 0
              icon: "x"
              baseSize: 24
              colorBg: "transparent"
              colorFg: Color.mOnSurfaceVariant
              onClicked: {
                searchTextInput.text = "";
                main?.executeSearch("");
              }
            }
          }
        }

        Timer {
          id: searchDebounce
          interval: 280
          repeat: false
          onTriggered: {
            main?.executeSearch(searchTextInput.text.trim());
          }
        }

        // Search Results List
        ListView {
          id: searchResultsView
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: Style.marginXS
          model: main?.searchResults || []

          delegate: Rectangle {
            width: searchResultsView.width
            implicitHeight: Math.round(50 * Style.uiScaleRatio)
            radius: Style.iRadiusS
            color: searchItemHover.hovered ? Color.mSurfaceVariant : "transparent"
            border.color: searchItemHover.hovered ? Style.boxBorderColor : "transparent"
            border.width: Style.borderS

            HoverHandler { id: searchItemHover }
            TapHandler {
              onTapped: main?.openNote(modelData.fullPath, "neovim")
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginS
              anchors.rightMargin: Style.marginXS
              spacing: Style.marginXS

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: Style.marginXS
                  Text {
                    text: modelData.title || ""
                    font.pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightBold
                    color: searchItemHover.hovered ? Color.mPrimary : Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Rectangle {
                    visible: !!modelData.source
                    implicitHeight: 16
                    implicitWidth: badgeText.implicitWidth + 8
                    radius: 8
                    color: modelData.source === "khoj" ? Color.mPrimary : Color.mSurfaceVariant
                    border.color: modelData.source === "khoj" ? "transparent" : Color.mOutline
                    border.width: Style.borderS

                    Text {
                      id: badgeText
                      anchors.centerIn: parent
                      text: modelData.source === "khoj" ? "AI" : (modelData.source === "filename" ? "Title" : "Text")
                      font.pointSize: Style.fontSizeXXS
                      font.weight: Style.fontWeightBold
                      color: modelData.source === "khoj" ? Color.mOnPrimary : Color.mOnSurfaceVariant
                    }
                  }
                }

                Text {
                  text: modelData.snippet || modelData.relPath || ""
                  font.pointSize: Style.fontSizeXXS
                  color: Color.mOnSurfaceVariant
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              NIconButton {
                icon: "external-link"
                tooltipText: "Open in Obsidian Desktop"
                baseSize: 26
                colorBg: "transparent"
                colorFg: Color.mOnSurfaceVariant
                onClicked: main?.openNote(modelData.fullPath, "obsidian")
              }
            }
          }

          Item {
            anchors.fill: parent
            visible: main?.isSearching
            Text {
              anchors.centerIn: parent
              text: "Searching..."
              font.pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          Item {
            anchors.fill: parent
            visible: !main?.isSearching && (!main?.searchResults || main?.searchResults.length === 0)
            Text {
              anchors.centerIn: parent
              text: "No notes found"
              font.pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }
        }
      }
    }
  }
}
