-- opencode.nvim (https://github.com/NickvanDyke/opencode.nvim)
--  Integrate the opencode AI assistant with Neovim — streamline editor-aware research, reviews, and requests.

--- Kill an opencode process group reliably.
--- Uses synchronous os.execute so it completes even during VimLeavePre
--- (vim.fn.system spawns async jobs that Neovim kills during shutdown).
--- Negative PID sends SIGTERM to the entire process group (children included).
--- SIGTERM is required because opencode respawns on SIGHUP (which jobstop/kill-pane send).
local function kill_opencode(pid)
  if pid and pid > 0 then
    os.execute("kill -TERM -" .. pid .. " 2>/dev/null")
  end
end

local function tmux_controller(cmd, opts)
  local pane_id
  opts = vim.tbl_deep_extend("force", {
    options = "-h",
    focus = false,
    allow_passthrough = false,
  }, opts or {})

  local function tmux_available()
    return vim.fn.executable("tmux") == 1 and vim.env.TMUX
  end

  local function get_pane_id()
    if not tmux_available() then
      return nil
    end

    if pane_id then
      if vim.fn.system("tmux list-panes -t " .. pane_id):match("can't find pane") then
        pane_id = nil
      end
    end

    return pane_id
  end

  local function start(cmd_override)
    if get_pane_id() then
      return
    end

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

    if opts.allow_passthrough ~= true and pane_id and pane_id ~= "" then
      vim.fn.system(string.format("tmux set-option -t %s -p allow-passthrough off", pane_id))
    end
  end

  local function stop()
    local active_pane = get_pane_id()
    if active_pane then
      -- Get the pane's PID and kill the process group with SIGTERM.
      local pid = vim.trim(
        vim.fn.system(string.format("tmux display-message -p -t %s '#{pane_pid}'", active_pane))
      )
      kill_opencode(tonumber(pid))
      -- Kill the tmux pane itself — it stays open after the process exits.
      vim.fn.system(string.format("tmux kill-pane -t %s", active_pane))
      pane_id = nil
    end
  end

  local function toggle(cmd_override)
    if get_pane_id() then
      stop()
    else
      start(cmd_override)
    end
  end

  return {
    start = start,
    stop = stop,
    toggle = toggle,
  }
end

-- Derive a unique port per Neovim instance from its PID to avoid conflicts
-- when running multiple sessions in parallel. Maps PID into the range 41000-65535.
local opencode_port = 41000 + (vim.fn.getpid() % 24535)
local opencode_cmd = "opencode --port " .. opencode_port

local tmux_server = vim.env.TMUX and tmux_controller(opencode_cmd) or nil

-- Cache PID for each snacks opencode terminal buffer so we can kill it
-- reliably during VimLeavePre (when terminal_job_id is no longer available).
local opencode_pids = {} -- buffer number -> PID

--- Build snacks.terminal opts for a given command.
--- Calls opencode.terminal.setup() for keymaps, then clears the
--- plugin's TermRequest autocmd that would steal focus back.
--- Eagerly caches the process PID in TermOpen for reliable cleanup.
local function snacks_opts(cmd)
  return {
    cmd = cmd or opencode_cmd,
    interactive = true,
    win = {
      position = "right",
      on_win = function(win)
        require("opencode.terminal").setup(win.win)
        -- The plugin's setup() registers a TermRequest autocmd that steals focus
        -- back to the previous window (startinsert | feedkeys C-\C-n C-w p).
        -- Clear it so Snacks.terminal's own focus/insert handling works.
        vim.schedule(function()
          pcall(vim.api.nvim_clear_autocmds, { event = "TermRequest", buffer = win.buf })
        end)

        -- Eagerly cache the PID so we can kill it during VimLeavePre
        -- (by then terminal_job_id may no longer be available).
        vim.api.nvim_create_autocmd("TermOpen", {
          buffer = win.buf,
          once = true,
          callback = function()
            local job_id = vim.b[win.buf].terminal_job_id
            if job_id then
              local ok, pid = pcall(vim.fn.jobpid, job_id)
              if ok and pid then
                opencode_pids[win.buf] = pid
              end
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
  for _, term in ipairs(Snacks.terminal.list()) do
    local term_cmd = term.cmd
    if type(term_cmd) == "string" and term_cmd:match("^opencode ") then
      -- Kill the process group first using the cached PID.
      local pid = opencode_pids[term.buf]
      kill_opencode(pid)
      if term.buf then
        opencode_pids[term.buf] = nil
      end
      term:close()
    end
  end
end

return {
  "NickvanDyke/opencode.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  lazy = true,
  cmd = "Opencode",
  keys = {
    {
      "<leader>ac",
      function() require("opencode").toggle() end,
      desc = "Toggle opencode terminal",
    },
    {
      "<leader>ar",
      function()
        -- Resume the last opencode session.
        -- Stop any existing server first to avoid opening a second terminal,
        -- since the resume cmd differs from the regular cmd (different snacks identity).
        require("opencode").stop()
        local resume_cmd = "opencode --continue --port " .. opencode_port
        if tmux_server then
          tmux_server.start(resume_cmd)
        else
          Snacks.terminal.open(resume_cmd, snacks_opts())
        end
      end,
      desc = "Resume last opencode session",
    },
    {
      "<leader>aa",
      function() require("opencode").ask("@this: ", { submit = false }) end,
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
      function() require("opencode").prompt("review") end,
      mode = { "n", "x" },
      desc = "Review with opencode",
    },
  },
  config = function()
    local server
    if tmux_server then
      server = {
        start = tmux_server.start,
        stop = tmux_server.stop,
        toggle = tmux_server.toggle,
      }
    else
      server = {
        start = function()
          close_snacks_opencode()
          Snacks.terminal.open(opencode_cmd, snacks_opts(opencode_cmd))
        end,
        stop = function() close_snacks_opencode() end,
        toggle = function()
          -- Check if any opencode terminal (regular or resume) is visible.
          -- If so, hide it (not close — close kills the process and triggers
          -- "exited with code -1"). Otherwise show a hidden one or open a new one.
          for _, term in ipairs(Snacks.terminal.list()) do
            local term_cmd = term.cmd
            if type(term_cmd) == "string" and term_cmd:match("^opencode ") and term:win_valid() then
              term:hide()
              return
            end
          end
          -- No visible opencode terminal — try to re-show a hidden one.
          for _, term in ipairs(Snacks.terminal.list()) do
            local term_cmd = term.cmd
            if type(term_cmd) == "string" and term_cmd:match("^opencode ") and term:buf_valid() then
              term:show()
              return
            end
          end
          -- None exists at all — open a new one.
          Snacks.terminal.open(opencode_cmd, snacks_opts(opencode_cmd))
        end,
      }
    end

    ---@type opencode.Opts
    vim.g.opencode_opts = vim.tbl_deep_extend("force", vim.g.opencode_opts or {}, {
      server = vim.tbl_deep_extend("force", server, {
        port = opencode_port,
      }),
    })

    vim.o.autoread = true

    -- Ensure the opencode process is stopped when Neovim exits to avoid zombie processes.
    -- Uses synchronous os.execute (via kill_opencode) to kill the process group,
    -- which survives VimLeavePre (unlike vim.fn.system which spawns async jobs).
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("opencode_terminal", { clear = true }),
      callback = function()
        if tmux_server then
          tmux_server.stop()
        else
          server.stop()
        end
      end,
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
