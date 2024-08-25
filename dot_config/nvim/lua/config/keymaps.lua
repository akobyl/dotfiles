-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- escape with jk
vim.keymap.set("i", "jk", "<esc>", { desc = "jk to escape" })

-- Bufferline Tabs
vim.keymap.set("n", "gh", ":BufferLinePick<cr>", { desc = "Select Tab" })
vim.keymap.set("n", "gq", ":BufferLinePickClose<cr>", { desc = "Select Tab to close" })

-- Rest Nvim
vim.keymap.set("n", "<leader>rr", "<cmd>Rest run<cr>", { desc = "Send Request" })

-- Go to in new window
vim.keymap.set("n", "gp", "<cmd>tab split | lua vim.lsp.buf.definition()<CR>", {})

-- Save in insert mode
vim.keymap.set("i", "jkl", "<C-O>:w<cr>", { desc = "Save in insert mode" })
vim.keymap.set("n", "jkl", "<C-O>:w<cr>", { desc = "Save in insert mode" })

-- Aerial commands
vim.keymap.set("n", "<leader>cb", "<cmd>AerialToggle<cr>", { desc = "Toggle Aerial Nav" })

-- DAP commands
vim.keymap.set("n", "<F10>", "<cmd>lua require'dap'.step_over()<cr>", { desc = "Step Over" })
vim.keymap.set("n", "<F11>", "<cmd>lua require'dap'.step_into()<cr>", { desc = "Step Into" })
vim.keymap.set("n", "<F12>", "<cmd>lua require'dap'.step_out()<cr>", { desc = "Step Out" })
vim.keymap.set("n", "<F9>", "<cmd>lua require'dap'.toggle_breakpoint()<cr>", { desc = "Toggle Breakpoint" })
vim.keymap.set("n", "<F5>", "<cmd>lua require'dap'.continue()<cr>", { desc = "Continue" })
vim.keymap.set("n", "<S-F5>", "<cmd>lua require'dap'.stop()<cr>", { desc = "Stop" })

-- Disable F1 cuz it's annoying
vim.keymap.set("n", "<F1>", "<Esc>")
vim.keymap.set("i", "<F1>", "<Esc>")
