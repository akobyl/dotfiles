-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.autoformat = true
vim.opt.relativenumber = false

if vim.g.neovide then
  vim.g.neovide_cursor_animation_length = 0
  --vim.o.guifont = "Sauce Code Pro Light:h16"
  vim.o.guifont = "FiraCode Nerd Font Light:h16"
end

-- silicon settings
-- vim.g.silicon["theme"] = "gruvbox"
-- vim.g.silicon["background"] = '#F6F0DC'
