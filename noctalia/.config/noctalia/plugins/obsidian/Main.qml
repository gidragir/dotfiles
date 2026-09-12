import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // Shared status state
  property var statusData: ({
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

  // Tags and Search reactive state
  property var tagsData: []
  property bool isLoadingTags: false
  property string selectedTag: ""
  property var notesForTag: []
  property bool isLoadingTagNotes: false

  property var searchResults: []
  property bool isSearching: false
  property string lastSearchQuery: ""

  // Settings shortcuts with safe fallbacks
  readonly property string vaultPath: pluginApi?.pluginSettings?.vaultPath
    || pluginApi?.manifest?.metadata?.defaultSettings?.vaultPath || "/data/obsidian"
  readonly property string dailyFolder: pluginApi?.pluginSettings?.dailyFolder
    || pluginApi?.manifest?.metadata?.defaultSettings?.dailyFolder || "DAILY"
  readonly property string preferredEditor: pluginApi?.pluginSettings?.preferredEditor
    || pluginApi?.manifest?.metadata?.defaultSettings?.preferredEditor || "neovim"
  readonly property int refreshIntervalSec: pluginApi?.pluginSettings?.refreshIntervalSec
    || pluginApi?.manifest?.metadata?.defaultSettings?.refreshIntervalSec || 15

  readonly property string helperScript: (pluginApi?.pluginDir || "") + "/scripts/obsidian-helper.sh"

  // Process to fetch status JSON
  Process {
    id: statusProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        var output = String(statusProc.stdout.text || "").trim();
        if (output) {
          try {
            var parsed = JSON.parse(output);
            root.statusData = parsed;
          } catch (e) {
            Logger.e("ObsidianCompanion", "Failed to parse status JSON: " + e);
          }
        }
      }
    }
  }

  // Process to fetch tags list
  Process {
    id: tagsProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: (exitCode, exitStatus) => {
      root.isLoadingTags = false;
      if (exitCode === 0) {
        try {
          var raw = String(tagsProc.stdout.text || "").trim();
          if (raw) root.tagsData = JSON.parse(raw);
        } catch (e) {
          Logger.e("ObsidianCompanion", "Failed to parse tags JSON: " + e);
        }
      }
    }
  }

  // Process to fetch notes for a specific tag
  Process {
    id: tagNotesProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: (exitCode, exitStatus) => {
      root.isLoadingTagNotes = false;
      if (exitCode === 0) {
        try {
          var raw = String(tagNotesProc.stdout.text || "").trim();
          if (raw) root.notesForTag = JSON.parse(raw);
        } catch (e) {
          Logger.e("ObsidianCompanion", "Failed to parse tag notes JSON: " + e);
        }
      }
    }
  }

  // Process to execute note search
  Process {
    id: searchProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: (exitCode, exitStatus) => {
      root.isSearching = false;
      if (exitCode === 0) {
        try {
          var raw = String(searchProc.stdout.text || "").trim();
          if (raw) root.searchResults = JSON.parse(raw);
        } catch (e) {
          Logger.e("ObsidianCompanion", "Failed to parse search JSON: " + e);
        }
      }
    }
  }

  function refreshStatus() {
    if (!statusProc.running && helperScript) {
      statusProc.command = ["bash", helperScript, "status", root.vaultPath, root.dailyFolder];
      statusProc.running = true;
    }
  }

  function fetchTags(force) {
    if ((root.tagsData.length > 0 && !force) || root.isLoadingTags) return;
    root.isLoadingTags = true;
    tagsProc.command = ["bash", helperScript, "list-tags-json", root.vaultPath];
    tagsProc.running = true;
  }

  function fetchNotesByTag(tag) {
    root.selectedTag = tag;
    root.isLoadingTagNotes = true;
    root.notesForTag = [];
    tagNotesProc.command = ["bash", helperScript, "notes-by-tag-json", tag, root.vaultPath];
    tagNotesProc.running = true;
  }

  function executeSearch(query) {
    root.lastSearchQuery = query;
    root.isSearching = true;
    searchProc.command = ["bash", helperScript, "search-notes-json", query, root.vaultPath];
    searchProc.running = true;
  }

  function openNote(path, overrideEditor) {
    var editor = overrideEditor || root.preferredEditor;
    Quickshell.execDetached(["bash", helperScript, "open-note", path, editor]);
  }

  // Periodic timer
  Timer {
    id: refreshTimer
    interval: Math.max(5, root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  Component.onCompleted: {
    refreshStatus();
  }

  onVaultPathChanged: refreshStatus()
  onDailyFolderChanged: refreshStatus()

  // Actions
  function capture(text, type) {
    if (!text || !text.trim()) return;
    Quickshell.execDetached(["bash", helperScript, "capture", text.trim(), type || "task", root.vaultPath, root.dailyFolder]);
    // Refresh after brief delay to catch the updated file
    refreshDelayTimer.restart();
  }

  function toggleTask(line) {
    if (!root.statusData.dailyFile || !line) return;
    Quickshell.execDetached(["bash", helperScript, "toggle-task", root.statusData.dailyFile, String(line)]);
    refreshDelayTimer.restart();
  }

  function openDaily(overrideEditor) {
    var editor = overrideEditor || root.preferredEditor;
    Quickshell.execDetached(["bash", helperScript, "open-daily", editor, root.vaultPath, root.dailyFolder]);
  }

  function syncVault() {
    Quickshell.execDetached(["bash", helperScript, "sync"]);
    refreshDelayTimer.restart();
  }

  function exploreTags() {
    Quickshell.execDetached(["bash", helperScript, "explore-tags", root.vaultPath]);
  }

  function searchNotes() {
    Quickshell.execDetached(["bash", helperScript, "search-notes", root.vaultPath]);
  }

  function createNote(type) {
    var cmd = "~/.zsh/scripts/obsidian-create-note.sh";
    if (type && type.trim()) cmd += " " + type.trim();
    Quickshell.execDetached(["bash", "-c", cmd]);
  }

  Timer {
    id: refreshDelayTimer
    interval: 350
    repeat: false
    onTriggered: root.refreshStatus()
  }

  // Smart open panel
  function openPanelSmart() {
    if (!pluginApi) return;
    pluginApi.withCurrentScreen(function(screen) {
      pluginApi.openPanel(screen);
    });
  }

  function togglePanelSmart() {
    if (!pluginApi) return;
    pluginApi.withCurrentScreen(function(screen) {
      pluginApi.togglePanel(screen);
    });
  }

  // IPC Handlers
  IpcHandler {
    target: "plugin:obsidian"

    function toggle() {
      root.togglePanelSmart();
    }

    function open() {
      root.openPanelSmart();
    }

    function close() {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(function(screen) {
        pluginApi.closePanel(screen);
      });
    }

    function refresh() {
      root.refreshStatus();
    }

    function sync() {
      root.syncVault();
    }

    function openDaily(editor: string) {
      root.openDaily(editor);
    }

    function capture(text: string, type: string) {
      root.capture(text, type || "task");
    }

    function exploreTags() {
      root.exploreTags();
    }

    function searchNotes() {
      root.searchNotes();
    }

    function newNote(type: string) {
      root.createNote(type);
    }
  }
}
