import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  // Edit state
  property string editVaultPath:
    pluginApi?.pluginSettings?.vaultPath
    || pluginApi?.manifest?.metadata?.defaultSettings?.vaultPath
    || "/data/obsidian"

  property string editDailyFolder:
    pluginApi?.pluginSettings?.dailyFolder
    || pluginApi?.manifest?.metadata?.defaultSettings?.dailyFolder
    || "DAILY"

  property string editDailyFormat:
    pluginApi?.pluginSettings?.dailyFormat
    || pluginApi?.manifest?.metadata?.defaultSettings?.dailyFormat
    || "YYYY-MM-DD"

  property string editPreferredEditor:
    pluginApi?.pluginSettings?.preferredEditor
    || pluginApi?.manifest?.metadata?.defaultSettings?.preferredEditor
    || "neovim"

  property bool editShowBadge:
    pluginApi?.pluginSettings?.showBadge
    ?? pluginApi?.manifest?.metadata?.defaultSettings?.showBadge
    ?? true

  property string editBadgeMode:
    pluginApi?.pluginSettings?.badgeMode
    || pluginApi?.manifest?.metadata?.defaultSettings?.badgeMode
    || "pending"

  property int editRefreshIntervalSec:
    pluginApi?.pluginSettings?.refreshIntervalSec
    || pluginApi?.manifest?.metadata?.defaultSettings?.refreshIntervalSec
    || 15

  property string editPanelPosition:
    pluginApi?.pluginSettings?.panelPosition
    || pluginApi?.manifest?.metadata?.defaultSettings?.panelPosition
    || "follow_launcher"

  // Options
  readonly property var editorOptions: [
    { key: "neovim",   name: root.pluginApi?.tr("settings.editorNeovim") || "Neovim (Terminal / Ghostty)" },
    { key: "obsidian", name: root.pluginApi?.tr("settings.editorObsidian") || "Obsidian App" },
    { key: "xdg-open", name: root.pluginApi?.tr("settings.editorDefault") || "System Default (xdg-open)" }
  ]

  readonly property var badgeOptions: [
    { key: "pending",   name: root.pluginApi?.tr("settings.badgeModePending") || "Pending tasks count (e.g. 3)" },
    { key: "fraction",  name: root.pluginApi?.tr("settings.badgeModeFraction") || "Fraction (e.g. 2/5)" },
    { key: "icon-only", name: root.pluginApi?.tr("settings.badgeModeIconOnly") || "Icon only" }
  ]

  readonly property var positionOptions: [
    { key: "follow_launcher", name: root.pluginApi?.tr("settings.positionFollowLauncher") || "Follow launcher" },
    { key: "center",          name: root.pluginApi?.tr("settings.positionCenter") || "Center" },
    { key: "top_center",      name: root.pluginApi?.tr("settings.positionTopCenter") || "Top center" },
    { key: "top_left",        name: root.pluginApi?.tr("settings.positionTopLeft") || "Top left" },
    { key: "top_right",       name: root.pluginApi?.tr("settings.positionTopRight") || "Top right" },
    { key: "bottom_center",   name: root.pluginApi?.tr("settings.positionBottomCenter") || "Bottom center" },
    { key: "bottom_left",     name: root.pluginApi?.tr("settings.positionBottomLeft") || "Bottom left" },
    { key: "bottom_right",    name: root.pluginApi?.tr("settings.positionBottomRight") || "Bottom right" }
  ]

  spacing: Style.marginM

  // ═══════════════════════════════════════
  // Vault Configuration
  // ═══════════════════════════════════════
  NLabel {
    label: root.pluginApi?.tr("settings.vaultSection") || "Vault Configuration"
  }

  NTextInput {
    Layout.fillWidth: true
    label: root.pluginApi?.tr("settings.vaultPath") || "Vault Path"
    description: root.pluginApi?.tr("settings.vaultPathDesc") || "Absolute path to Obsidian vault"
    placeholderText: "/data/obsidian"
    text: root.editVaultPath
    onTextChanged: root.editVaultPath = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: root.pluginApi?.tr("settings.dailyFolder") || "Daily Notes Folder"
    description: root.pluginApi?.tr("settings.dailyFolderDesc") || "Folder path inside vault"
    placeholderText: "DAILY"
    text: root.editDailyFolder
    onTextChanged: root.editDailyFolder = text
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  // ═══════════════════════════════════════
  // Behavior & Editor
  // ═══════════════════════════════════════
  NLabel {
    label: root.pluginApi?.tr("settings.behaviorSection") || "Behavior & UI"
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.pluginApi?.tr("settings.preferredEditor") || "Preferred Editor"
    description: root.pluginApi?.tr("settings.preferredEditorDesc") || "Application for daily notes"
    model: root.editorOptions
    currentKey: root.editPreferredEditor
    onSelected: function(key) {
      root.editPreferredEditor = key;
    }
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.pluginApi?.tr("settings.panelPosition") || "Panel Position"
    description: root.pluginApi?.tr("settings.panelPositionDesc") || "Where the hub appears"
    model: root.positionOptions
    currentKey: root.editPanelPosition
    onSelected: function(key) {
      root.editPanelPosition = key;
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: root.pluginApi?.tr("settings.showBadge") || "Show Task Badge on Bar"
    description: root.pluginApi?.tr("settings.showBadgeDesc") || "Display count next to icon"
    checked: root.editShowBadge
    onToggled: function(v) { root.editShowBadge = v }
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.pluginApi?.tr("settings.badgeMode") || "Badge Mode"
    description: root.pluginApi?.tr("settings.badgeModeDesc") || "How task count is displayed"
    model: root.badgeOptions
    currentKey: root.editBadgeMode
    onSelected: function(key) {
      root.editBadgeMode = key;
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: root.pluginApi?.tr("settings.refreshInterval", { seconds: root.editRefreshIntervalSec }) || ("Refresh Interval: " + root.editRefreshIntervalSec + "s")
      description: root.pluginApi?.tr("settings.refreshIntervalDesc", { seconds: root.editRefreshIntervalSec }) || "Interval in seconds"
    }

    NSlider {
      Layout.fillWidth: true
      from: 5
      to: 120
      stepSize: 5
      value: root.editRefreshIntervalSec
      onValueChanged: root.editRefreshIntervalSec = value
    }
  }

  // ── Save function ──
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("ObsidianCompanion", "Cannot save: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.vaultPath = root.editVaultPath;
    pluginApi.pluginSettings.dailyFolder = root.editDailyFolder;
    pluginApi.pluginSettings.dailyFormat = root.editDailyFormat;
    pluginApi.pluginSettings.preferredEditor = root.editPreferredEditor;
    pluginApi.pluginSettings.showBadge = root.editShowBadge;
    pluginApi.pluginSettings.badgeMode = root.editBadgeMode;
    pluginApi.pluginSettings.refreshIntervalSec = root.editRefreshIntervalSec;
    pluginApi.pluginSettings.panelPosition = root.editPanelPosition;

    pluginApi.saveSettings();
    Logger.i("ObsidianCompanion", "Settings saved successfully");
  }
}
