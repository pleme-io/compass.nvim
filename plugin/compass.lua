if vim.g.loaded_compass then
  return
end
vim.g.loaded_compass = true

vim.api.nvim_create_user_command("Compass", function()
  require("compass").open()
end, { desc = "Open Compass project navigator" })

vim.api.nvim_create_user_command("CompassRefresh", function()
  require("compass").refresh()
  vim.notify("[compass] Projects refreshed", vim.log.levels.INFO)
end, { desc = "Refresh Compass project list" })
