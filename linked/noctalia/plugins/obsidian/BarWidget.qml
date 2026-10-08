import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Noctalia
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen: null
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property var pluginApi: null

  readonly property var main: pluginApi?.mainInstance ?? null
  readonly property var statusData: main?.statusData ?? ({
    "totalTasks": 0,
    "completedTasks": 0,
    "pendingTasks": 0,
    "syncStatus": "idle",
    "exists": false,
    "todayFormatted": ""
  })

  // Settings
  readonly property bool showBadge: pluginApi?.pluginSettings?.showBadge
    ?? pluginApi?.manifest?.metadata?.defaultSettings?.showBadge ?? true
  readonly property string badgeMode: pluginApi?.pluginSettings?.badgeMode
    || pluginApi?.manifest?.metadata?.defaultSettings?.badgeMode || "pending"

  readonly property int totalTasks: statusData.totalTasks || 0
  readonly property int completedTasks: statusData.completedTasks || 0
  readonly property int pendingTasks: statusData.pendingTasks || 0
  readonly property string syncStatus: statusData.syncStatus || "idle"

  // Icon & Text calculation
  readonly property string barIcon: totalTasks > 0 ? "checklist" : "notebook"

  readonly property string badgeText: {
    if (!showBadge) return "";
    if (badgeMode === "fraction") {
      return totalTasks > 0 ? (completedTasks + "/" + totalTasks) : "";
    }
    if (badgeMode === "icon-only") {
      return "";
    }
    // Default: "pending"
    if (pendingTasks > 0) {
      return String(pendingTasks);
    }
    if (totalTasks > 0 && pendingTasks === 0) {
      return "✓";
    }
    return "";
  }

  // Tooltip content
  readonly property string tooltipContent: {
    var lines = [];
    lines.push("<b>" + (pluginApi?.tr("bar.tooltipTitle") || "Obsidian Companion") + "</b>");
    if (statusData.todayFormatted) {
      lines.push(statusData.todayFormatted);
    }
    if (totalTasks > 0) {
      lines.push((pluginApi?.tr("panel.tasksProgress", { completed: completedTasks, total: totalTasks }) || (completedTasks + "/" + totalTasks + " done")));
    } else {
      lines.push(pluginApi?.tr("bar.noTasks") || "No tasks for today");
    }
    lines.push(pluginApi?.tr("bar.syncStatus", { status: syncStatus }) || ("Sync: " + syncStatus));
    lines.push("<font color='" + Color.mOutline + "'>" + (pluginApi?.tr("bar.clickAction") || "LMB: Hub · RMB: Menu · MMB: Capture") + "</font>");
    return lines.join("<br/>");
  }

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.barIcon
    text: root.badgeText
    autoHide: false
    forceOpen: root.badgeText !== ""
    forceClose: root.badgeText === ""
    tooltipText: root.tooltipContent

    customIconColor: {
      if (syncStatus === "error") return Color.mError;
      if (pendingTasks > 0) return Color.mPrimary;
      if (totalTasks > 0 && pendingTasks === 0) return Color.mTertiary;
      return Color.mOnSurface;
    }

    customTextColor: {
      if (pendingTasks > 0) return Color.mPrimary;
      if (totalTasks > 0 && pendingTasks === 0) return Color.mTertiary;
      return Color.mOnSurface;
    }

    onClicked: {
      if (pluginApi) {
        pluginApi.togglePanel(screen, pill);
      }
    }

    onRightClicked: {
      PanelService.showContextMenu(contextMenu, pill, screen);
    }

    onMiddleClicked: {
      if (pluginApi) {
        pluginApi.togglePanel(screen, pill);
      }
    }
  }

  // Sync dot indicator
  Rectangle {
    id: syncDot
    width: 6
    height: 6
    radius: Style.radiusXS
    anchors.top: parent.top
    anchors.topMargin: 4
    anchors.right: parent.right
    anchors.rightMargin: 4
    visible: syncStatus === "syncing" || syncStatus === "error"
    color: syncStatus === "error" ? Color.mError : Color.mPrimary

    SequentialAnimation on opacity {
      running: syncStatus === "syncing"
      loops: Animation.Infinite
      PropertyAnimation { to: 0.2; duration: 600 }
      PropertyAnimation { to: 1.0; duration: 600 }
    }
  }

  // Right-click context menu
  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.openDailyNeovim") || "Open Today's Note (Neovim)",
        "action": "open-daily-neovim",
        "icon": "terminal"
      },
      {
        "label": pluginApi?.tr("menu.openDailyObsidian") || "Open Today's Note (Obsidian)",
        "action": "open-daily-obsidian",
        "icon": "notes"
      },
      {
        "label": pluginApi?.tr("menu.exploreTags") || "Explore Tags (Glow)",
        "action": "explore-tags",
        "icon": "tag"
      },
      {
        "label": pluginApi?.tr("menu.searchNotes") || "Search Notes",
        "action": "search-notes",
        "icon": "search"
      },
      {
        "label": pluginApi?.tr("menu.syncVault") || "Sync Vault Now",
        "action": "sync-vault",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("menu.settings") || "Settings",
        "action": "open-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "open-daily-neovim") {
        main?.openDaily("neovim");
      } else if (action === "open-daily-obsidian") {
        main?.openDaily("obsidian");
      } else if (action === "explore-tags") {
        main?.exploreTags();
      } else if (action === "search-notes") {
        main?.searchNotes();
      } else if (action === "sync-vault") {
        main?.syncVault();
      } else if (action === "open-settings") {
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, {});
      }
    }
  }
}
