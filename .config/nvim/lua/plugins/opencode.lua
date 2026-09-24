-- opencode.nvim (https://github.com/NickvanDyke/opencode.nvim)
--  Integrate the opencode AI assistant with Neovim — streamline editor-aware research, reviews, and requests.

--- Kill an opencode process group reliably.
--- Uses synchronous os.execute so it completes even during VimLeavePre
--- (vim.fn.system spawns async jobs that Neovim kills during shutdown).
--- Negative PID sends SIGTERM to the entire process group (children included).
--- SIGTERM is required because opencode respawns on SIGHUP (which jobstop/kill-pane send).
local function kill_opencode(pid)
  if pid and pid > 0 then os.execute("kill -TERM -" .. pid .. " 2>/dev/null") end
end

local function tmux_controller(cmd, opts)
  local pane_id
  opts = vim.tbl_deep_extend("force", {
    options = "-h",
    focus = false,
    allow_passthrough = false,
  }, opts or {})

  local function get_pane_id()
    if vim.fn.executable("tmux") ~= 1 or not vim.env.TMUX then return nil end
    if pane_id and vim.fn.system("tmux list-panes -t " .. pane_id):match("can't find pane") then pane_id = nil end
    return pane_id
  end

  local function start(cmd_override)
    if get_pane_id() then return end

    local detach_flag = opts.focus and "" or "-d"
    pane_id = vim.trim(
      vim.fn.system(
        string.format(
          "tmux split-window %s -P -F '#{pane_id}' %s '%s'",
          detach_flag,
          opts.options or "",
          cmd_override or cmd
        )
      )
    )

    if not opts.allow_passthrough and pane_id and pane_id ~= "" then
      vim.fn.system(string.format("tmux set-option -t %s -p allow-passthrough off", pane_id))
    end
  end

  local function stop()
    local active_pane = get_pane_id()
    if not active_pane then return end

    local pid = vim.trim(vim.fn.system(string.format("tmux display-message -p -t %s '#{pane_pid}'", active_pane)))
    kill_opencode(tonumber(pid))
    vim.fn.system(string.format("tmux kill-pane -t %s", active_pane))
    pane_id = nil
  end

  local function focus()
    local active_pane = get_pane_id()
    if active_pane then vim.fn.system(string.format("tmux select-pane -t %s", active_pane)) end
  end

  local function toggle(cmd_override)
    if get_pane_id() then
      stop()
    else
      start(cmd_override)
      focus()
    end
  end

  return { start = start, stop = stop, toggle = toggle, focus = focus }
end

-- OpenCode 2 runs a shared background service that opencode.nvim discovers
-- on its own, so the TUI no longer needs a per-instance `--port`.
local opencode_cmd = "opencode"
local opencode_resume_cmd = "opencode --continue"

local tmux_server = vim.env.TMUX and tmux_controller(opencode_cmd) or nil

-- Cache PID for each snacks opencode terminal buffer so we can kill it
-- reliably during VimLeavePre (when terminal_job_id is no longer available).
local opencode_pids = {} -- buffer number -> PID

--- Add the navigation keymaps that opencode.nvim no longer manages.
--- OpenCode 2 removed the TUI control API, so each keymap sends the TUI's
--- default binding for the command straight to the terminal job.
---@param buf integer
local function setup_terminal_keymaps(buf)
  local function send(keys)
    return function()
      local job_id = vim.b[buf].terminal_job_id
      if job_id then vim.api.nvim_chan_send(job_id, keys) end
    end
  end

  local keymaps = {
    { "<C-u>", "\27\21", "Scroll up half page" }, -- session.half.page.up: ctrl+alt+u
    { "<C-d>", "\27\4", "Scroll down half page" }, -- session.half.page.down: ctrl+alt+d
    { "gg", "\7", "Go to first message" }, -- session.first: ctrl+g
    { "G", "\27\7", "Go to last message" }, -- session.last: ctrl+alt+g
    { "<Esc>", "\27", "Interrupt current session" }, -- session.interrupt: escape
  }
  for _, keymap in ipairs(keymaps) do
    vim.keymap.set("n", keymap[1], send(keymap[2]), { buffer = buf, desc = keymap[3] })
  end
end

--- Find the first snacks opencode terminal matching a predicate.
--- When no predicate is given, returns any opencode terminal.
local function find_opencode_term(predicate)
  for _, term in ipairs(Snacks.terminal.list()) do
    if type(term.cmd) == "string" and term.cmd:match("^opencode%f[%s%z]") and (not predicate or predicate(term)) then
      return term
    end
  end
end

--- Build snacks.terminal opts for the opencode TUI.
--- Adds terminal keymaps and eagerly caches the process PID in TermOpen
--- for reliable cleanup.
local function snacks_opts()
  return {
    cmd = opencode_cmd,
    interactive = true,
    win = {
      position = "right",
      on_win = function(win)
        -- Eagerly cache the PID so we can kill it during VimLeavePre
        -- (by then terminal_job_id may no longer be available).
        vim.api.nvim_create_autocmd("TermOpen", {
          buffer = win.buf,
          once = true,
          callback = function()
            setup_terminal_keymaps(win.buf)
            local job_id = vim.b[win.buf].terminal_job_id
            if job_id then
              local ok, pid = pcall(vim.fn.jobpid, job_id)
              if ok and pid then opencode_pids[win.buf] = pid end
            end
          end,
        })
      end,
    },
  }
end

--- Kill and close any active snacks opencode terminal (regular or resume).
--- Kills the process group FIRST (synchronous os.execute), THEN closes the window.
local function close_snacks_opencode()
  local term = find_opencode_term()
  while term do
    kill_opencode(opencode_pids[term.buf])
    if term.buf then opencode_pids[term.buf] = nil end
    term:close()
    term = find_opencode_term()
  end
end

local function start_opencode()
  if tmux_server then
    tmux_server.start()
    return
  end

  close_snacks_opencode()
  local prev_win = vim.api.nvim_get_current_win()
  Snacks.terminal.open(opencode_cmd, snacks_opts())
  if vim.api.nvim_win_is_valid(prev_win) then vim.api.nvim_set_current_win(prev_win) end
end

local function stop_opencode()
  if tmux_server then
    tmux_server.stop()
  else
    close_snacks_opencode()
  end
end

local function toggle_opencode()
  if tmux_server then
    tmux_server.toggle()
    return
  end

  local visible = find_opencode_term(function(t) return t:win_valid() end)
  if visible then
    visible:hide()
    return
  end

  local hidden = find_opencode_term(function(t) return t:buf_valid() end)
  if hidden then
    hidden:show()
  else
    Snacks.terminal.open(opencode_cmd, snacks_opts())
  end
end

--- Focus the opencode terminal panel (show it if hidden).
local function focus_opencode_term()
  if tmux_server then
    tmux_server.focus()
  else
    local term = find_opencode_term(function(t) return t:buf_valid() end)
    if term then term:show() end
  end
end

return {
  "NickvanDyke/opencode.nvim",
  dependencies = { "folke/snacks.nvim" },
  lazy = true,
  cmd = "OpenCode",
  keys = {
    {
      "<leader>ac",
      toggle_opencode,
      desc = "Toggle opencode terminal",
    },
    {
      "<leader>ar",
      function()
        -- Resume the last opencode session.
        -- Stop any existing server first to avoid opening a second terminal,
        -- since the resume cmd differs from the regular cmd (different snacks identity).
        stop_opencode()
        if tmux_server then
          tmux_server.start(opencode_resume_cmd)
        else
          Snacks.terminal.open(opencode_resume_cmd, snacks_opts())
        end
      end,
      desc = "Resume last opencode session",
    },
    {
      "<leader>aa",
      function() require("opencode").ask("@this: ") end,
      mode = { "n", "x" },
      desc = "Ask opencode…",
    },
    {
      "<leader>as",
      function() require("opencode").select() end,
      mode = { "n", "x" },
      desc = "Select opencode action…",
    },
    {
      "<leader>ap",
      function() require("opencode").prompt(require("opencode.config").opts.select.prompts.review) end,
      mode = { "n", "x" },
      desc = "Review with opencode",
    },
  },
  config = function()
    vim.api.nvim_create_user_command("OpenCode", toggle_opencode, { desc = "Toggle OpenCode terminal" })

    ---@type opencode.Opts
    vim.g.opencode_opts = vim.tbl_deep_extend("force", vim.g.opencode_opts or {}, {
      server = {
        start = start_opencode,
      },
    })

    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("opencode_focus", { clear = true }),
      pattern = "OpencodeEvent:session.execution.started",
      callback = function(args)
        local server = require("opencode.server").connected
        local session_id = args.data.event.data.sessionID
        if not server or server.url ~= args.data.url or not session_id then return end

        local directory = vim.fn.getcwd()
        server
          :resolve_session()
          :next(function(session)
            if vim.fn.getcwd() == directory and session.id == session_id then focus_opencode_term() end
          end)
          :catch(function() end)
      end,
      desc = "Focus OpenCode when the current project session starts working",
    })

    -- Ensure the opencode process is stopped when Neovim exits to avoid zombie processes.
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("opencode_terminal", { clear = true }),
      callback = stop_opencode,
    })
  end,
  specs = {
    {
      "folke/which-key.nvim",
      opts = {
        ---@module "which-key"
        ---@type wk.Spec
        spec = {
          { "<leader>a", group = "AI (opencode)" },
        },
      },
      opts_extend = { "spec" },
    },
  },
}
