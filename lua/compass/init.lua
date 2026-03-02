local M = {}

M.config = {
  roots = { "~/code" },
  max_depth = 4,
  restore_last_file = true,
}

local core = nil

local function load_core()
  if core then
    return core
  end
  local ok, mod = pcall(require, "compass_core")
  if not ok then
    vim.notify("[compass] Failed to load native module: " .. tostring(mod), vim.log.levels.ERROR)
    return nil
  end
  core = mod
  return core
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  load_core()
end

function M.refresh()
  local c = load_core()
  if not c then
    return {}
  end
  return c.scan(M.config.roots, M.config.max_depth)
end

function M.open()
  local c = load_core()
  if not c then
    return
  end
  local projects = c.scan(M.config.roots, M.config.max_depth)
  require("compass.ui").open(projects, M)
end

function M.select(project)
  if not project then
    return
  end
  local c = load_core()
  if c then
    c.track_open(project.path)
  end

  vim.cmd("cd " .. vim.fn.fnameescape(project.path))

  if M.config.restore_last_file then
    M._restore_last_file(project.path)
  end

  vim.notify("[compass] " .. project.display, vim.log.levels.INFO)
end

function M._restore_last_file(project_path)
  local oldfiles = vim.v.oldfiles or {}
  for _, f in ipairs(oldfiles) do
    if vim.startswith(f, project_path) and vim.fn.filereadable(f) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(f))
      return
    end
  end
end

function M.filter(query)
  local c = load_core()
  if not c then
    return {}
  end
  return c.filter(query)
end

return M
