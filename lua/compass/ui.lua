local M = {}

local buf = nil
local win = nil
local input_buf = nil
local input_win = nil
local results_buf = nil
local results_win = nil

local current_projects = {}
local selected_idx = 1
local compass_mod = nil

local ns = vim.api.nvim_create_namespace("compass")

local function close()
  local windows = { input_win, results_win, win }
  for _, w in ipairs(windows) do
    if w and vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
  end
  local buffers = { input_buf, results_buf, buf }
  for _, b in ipairs(buffers) do
    if b and vim.api.nvim_buf_is_valid(b) then
      vim.api.nvim_buf_delete(b, { force = true })
    end
  end
  input_win = nil
  results_win = nil
  win = nil
  input_buf = nil
  results_buf = nil
  buf = nil
end

local function render_projects()
  if not results_buf or not vim.api.nvim_buf_is_valid(results_buf) then
    return
  end

  local lines = {}
  for i, p in ipairs(current_projects) do
    local score_str = ""
    if p.score and p.score > 0 then
      score_str = string.format("  [%.0f]", p.score)
    end
    lines[i] = string.format("  %s%s", p.display or p.name, score_str)
  end

  if #lines == 0 then
    lines = { "  No projects found" }
  end

  vim.api.nvim_buf_set_option(results_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(results_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(results_buf, "modifiable", false)

  -- Highlight selected line
  vim.api.nvim_buf_clear_namespace(results_buf, ns, 0, -1)
  if selected_idx >= 1 and selected_idx <= #current_projects then
    vim.api.nvim_buf_add_highlight(results_buf, ns, "CursorLine", selected_idx - 1, 0, -1)
  end
end

local function move_selection(delta)
  local count = #current_projects
  if count == 0 then
    return
  end
  selected_idx = ((selected_idx - 1 + delta) % count) + 1
  render_projects()
end

local function confirm_selection()
  if selected_idx >= 1 and selected_idx <= #current_projects then
    local project = current_projects[selected_idx]
    close()
    if compass_mod then
      compass_mod.select(project)
    end
  end
end

local function on_input_changed()
  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)
  local query = (lines[1] or ""):gsub("^> ", "")

  if query == "" then
    -- Show all projects (already sorted by frecency from scan)
    if compass_mod then
      current_projects = compass_mod.refresh()
    end
  else
    current_projects = compass_mod and compass_mod.filter(query) or {}
  end

  selected_idx = 1
  render_projects()
end

function M.open(projects, mod)
  if win and vim.api.nvim_win_is_valid(win) then
    close()
  end

  compass_mod = mod
  current_projects = projects or {}
  selected_idx = 1

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  local width = math.min(80, math.floor(editor_width * 0.6))
  local height = math.min(30, math.floor(editor_height * 0.6))
  local row = math.floor((editor_height - height) / 2) - 1
  local col = math.floor((editor_width - width) / 2)

  -- Border window
  buf = vim.api.nvim_create_buf(false, true)
  win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Compass ",
    title_pos = "center",
  })
  vim.api.nvim_win_set_option(win, "winblend", 0)

  -- Input buffer (1 line at top)
  input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "> " })
  input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    width = width - 2,
    height = 1,
    row = row + 1,
    col = col + 1,
    style = "minimal",
    border = "none",
  })

  -- Results buffer (below input)
  results_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(results_buf, "modifiable", false)
  results_win = vim.api.nvim_open_win(results_buf, false, {
    relative = "editor",
    width = width - 2,
    height = height - 3,
    row = row + 3,
    col = col + 1,
    style = "minimal",
    border = "none",
  })
  vim.api.nvim_win_set_option(results_win, "cursorline", false)

  render_projects()

  -- Start in insert mode at end of prompt
  vim.cmd("startinsert!")

  -- Keymaps for input buffer
  local kopts = { buffer = input_buf, noremap = true, silent = true }
  vim.keymap.set("i", "<CR>", confirm_selection, kopts)
  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
    close()
  end, kopts)
  vim.keymap.set("i", "<C-j>", function()
    move_selection(1)
  end, kopts)
  vim.keymap.set("i", "<C-k>", function()
    move_selection(-1)
  end, kopts)
  vim.keymap.set("i", "<C-n>", function()
    move_selection(1)
  end, kopts)
  vim.keymap.set("i", "<C-p>", function()
    move_selection(-1)
  end, kopts)
  vim.keymap.set("n", "<Esc>", close, kopts)
  vim.keymap.set("n", "q", close, kopts)
  vim.keymap.set("n", "<CR>", confirm_selection, kopts)

  -- Auto-filter on text change
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = input_buf,
    callback = on_input_changed,
  })

  -- Close on buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = input_buf,
    once = true,
    callback = function()
      vim.schedule(close)
    end,
  })
end

return M
