-- common.lua
-- Shared WezTerm configuration for Personal and Work profiles

local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
local M = {}

function M.apply(config)
  -- Color scheme
  config.color_scheme = "GruvboxDarkHard"

  -- Font (size set per-profile)
  config.font = wezterm.font("MesloLGS Nerd Font Mono")

  -- Terminal settings
  config.term = "wezterm" -- Full Kitty protocol support
  config.enable_kitty_keyboard = true
  config.enable_csi_u_key_encoding = false -- Use Kitty protocol instead

  -- Window/tab settings
  config.initial_cols = 132 -- Overridden in Work profile
  config.initial_rows = 40
  config.scrollback_lines = 100000 -- Unlimited-ish
  config.enable_scroll_bar = false

  -- Cursor
  config.default_cursor_style = "BlinkingUnderline"
  config.cursor_blink_rate = 500

  -- Visual bell (no audible)
  config.audible_bell = "Disabled"
  config.visual_bell = {
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 75,
    target = "CursorColor",
  }

  -- macOS specific
  config.send_composed_key_when_left_alt_is_pressed = false -- Option sends Esc+
  config.send_composed_key_when_right_alt_is_pressed = true -- Right Option normal

  -- Disable SSH domain parsing (use regular SSH via keybindings instead)
  -- WezTerm's libssh-rs has compatibility issues with some SSH configs
  config.ssh_domains = {}

  -- Tab bar - use native macOS style
  config.use_fancy_tab_bar = true
  config.window_frame = {
    font = wezterm.font({ family = "SF Pro", weight = "Medium" }),
    font_size = 13.0,
  }
  config.window_decorations = "TITLE|RESIZE"
  config.hide_tab_bar_if_only_one_tab = true
  config.tab_bar_at_bottom = false

  -- Tab title with icons based on running process
  local process_icons = {
    ["zsh"] = wezterm.nerdfonts.dev_terminal,
    ["bash"] = wezterm.nerdfonts.dev_terminal,
    ["fish"] = wezterm.nerdfonts.dev_terminal,
    ["nvim"] = wezterm.nerdfonts.custom_neovim,
    ["vim"] = wezterm.nerdfonts.dev_vim,
    ["ssh"] = wezterm.nerdfonts.md_server,
    ["git"] = wezterm.nerdfonts.dev_git,
    ["lazygit"] = wezterm.nerdfonts.dev_git,
    ["node"] = wezterm.nerdfonts.md_nodejs,
    ["ruby"] = wezterm.nerdfonts.dev_ruby,
    ["rails"] = wezterm.nerdfonts.dev_ruby_on_rails,
    ["python"] = wezterm.nerdfonts.dev_python,
    ["python3"] = wezterm.nerdfonts.dev_python,
    ["docker"] = wezterm.nerdfonts.dev_docker,
    ["psql"] = wezterm.nerdfonts.dev_postgresql,
    ["pgcli"] = wezterm.nerdfonts.dev_postgresql,
    ["clickhouse"] = wezterm.nerdfonts.md_database,
    ["lnav"] = wezterm.nerdfonts.md_file_document,
    ["htop"] = wezterm.nerdfonts.md_chart_line,
    ["btop"] = wezterm.nerdfonts.md_chart_line,
    ["top"] = wezterm.nerdfonts.md_chart_line,
    ["make"] = wezterm.nerdfonts.seti_makefile,
    ["cargo"] = wezterm.nerdfonts.dev_rust,
    ["go"] = wezterm.nerdfonts.seti_go,
    ["kubectl"] = wezterm.nerdfonts.md_kubernetes,
  }

  -- Helper function to build a window/tab title
  local function get_title_with_icon(pane, tab_title)
    local process = pane.foreground_process_name or ""
    process = process:gsub(".*/", "")

    local title = tab_title
    if not title or #title == 0 then
      title = pane.title
    end
    if not title or #title == 0 then
      title = process
    end
    if not title or #title == 0 then
      title = "WezTerm"
    end

    local icon = process_icons[process] or wezterm.nerdfonts.dev_terminal
    return icon, title
  end

  -- Window title (shown in title bar, especially when tab bar is hidden)
  -- No icons here - the title bar font doesn't support Nerd Font icons
  wezterm.on("format-window-title", function(tab, pane, tabs, panes, cfg)
    local _, title = get_title_with_icon(pane, tab.tab_title)

    -- Show workspace name if available
    local workspace = wezterm.mux.get_active_workspace()
    if workspace and workspace ~= "default" then
      return workspace .. " - " .. title
    end
    return title
  end)

  wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local pane = tab.active_pane
    local title = tab.tab_title
    if not title or #title == 0 then
      title = pane.title
    end

    -- Get the foreground process name
    local process = pane.foreground_process_name or ""
    process = process:gsub(".*/", "") -- Remove path, keep just the process name

    -- Find matching icon
    local icon = process_icons[process] or wezterm.nerdfonts.dev_terminal

    -- Add icon and padding around the title
    return " " .. icon .. " " .. title .. " "
  end)

  -- Keybindings (iTerm2-like)
  config.keys = {
    -- Pane splits
    { key = "d", mods = "CMD", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "d", mods = "CMD|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

    -- Pane navigation
    { key = "[", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Prev") },
    { key = "]", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Next") },
    { key = "LeftArrow", mods = "CTRL|CMD", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "RightArrow", mods = "CTRL|CMD", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "UpArrow", mods = "CTRL|CMD", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "DownArrow", mods = "CTRL|CMD", action = wezterm.action.ActivatePaneDirection("Down") },

    -- Close pane (no confirmation - panes can be restored)
    { key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane({ confirm = false }) },

    -- Scrollback (use Shift+PgUp/PgDown to avoid conflicts with Neovim)
    { key = "Home", mods = "CMD", action = wezterm.action.ScrollToTop },
    { key = "End", mods = "CMD", action = wezterm.action.ScrollToBottom },
    { key = "PageUp", mods = "SHIFT", action = wezterm.action.ScrollByPage(-1) },
    { key = "PageDown", mods = "SHIFT", action = wezterm.action.ScrollByPage(1) },

    -- Profile hotkeys (spawn SSH sessions with custom tab titles)
    {
      key = "n",
      mods = "CTRL|CMD",
      action = wezterm.action_callback(function(win, pane)
        local tab, pane, window = win:mux_window():spawn_tab({ args = { "ssh", "nas" } })
        tab:set_title("nas")
      end),
    },
    {
      key = "u",
      mods = "CTRL|CMD",
      action = wezterm.action_callback(function(win, pane)
        local tab, pane, window = win:mux_window():spawn_tab({ args = { "ssh", "unifi" } })
        tab:set_title("unifi")
      end),
    },

    -- Resurrect plugin keybindings
    -- Save current workspace state (Cmd+Ctrl+S to avoid Alfred conflict)
    {
      key = "s",
      mods = "CMD|CTRL",
      action = wezterm.action_callback(function(win, pane)
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
      end),
    },
    -- Restore state (shows fuzzy finder)
    {
      key = "r",
      mods = "CMD|CTRL",
      action = wezterm.action_callback(function(win, pane)
        resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
          local type = string.match(id, "^([^/]+)") -- match before '/'
          id = string.match(id, "([^/]+)$") -- match after '/'
          id = string.match(id, "(.+)%..+$") -- remove file extension
          local opts = {
            relative = true,
            restore_text = true,
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
          }
          if type == "workspace" then
            local state = resurrect.state_manager.load_state(id, "workspace")
            resurrect.workspace_state.restore_workspace(state, opts)
          elseif type == "window" then
            local state = resurrect.state_manager.load_state(id, "window")
            resurrect.window_state.restore_window(pane:window(), state, opts)
          elseif type == "tab" then
            local state = resurrect.state_manager.load_state(id, "tab")
            resurrect.tab_state.restore_tab(pane:tab(), state, opts)
          end
        end)
      end),
    },
  }

  -- Resurrect plugin: periodic save (every 5 minutes)
  resurrect.state_manager.periodic_save({
    interval_seconds = 300,
    save_workspaces = true,
    save_windows = true,
    save_tabs = true,
  })

  -- Mouse bindings (iTerm2-like: copy on selection)
  config.mouse_bindings = {
    -- Copy to clipboard when selection is completed (mouse release)
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "NONE",
      action = wezterm.action.CompleteSelection("ClipboardAndPrimarySelection"),
    },
    -- Double-click selects word and copies
    {
      event = { Up = { streak = 2, button = "Left" } },
      mods = "NONE",
      action = wezterm.action.CompleteSelection("ClipboardAndPrimarySelection"),
    },
    -- Triple-click selects line and copies
    {
      event = { Up = { streak = 3, button = "Left" } },
      mods = "NONE",
      action = wezterm.action.CompleteSelection("ClipboardAndPrimarySelection"),
    },
    -- Right-click pastes from clipboard
    {
      event = { Down = { streak = 1, button = "Right" } },
      mods = "NONE",
      action = wezterm.action.PasteFrom("Clipboard"),
    },
  }
end

return M
