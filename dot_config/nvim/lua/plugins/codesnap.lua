-- return {
--   "mistricky/codesnap.nvim",
--   build = "make build_generator",
--   keys = {
--     { "<leader>cc", "<cmd>CodeSnap<cr>", mode = "x", desc = "Save selected code snapshot into clipboard" },
--     { "<leader>cs", "<cmd>CodeSnapSave<cr>", mode = "x", desc = "Save selected code snapshot in ~/Pictures" },
--   },
--   opts = {
--     save_path = "~/Pictures",
--     has_breadcrumbs = true,
--     bg_theme = "bamboo",
--   },
-- }
-- return {
--   "segeljakt/vim-silicon",
--
-- }
-- return {
--   	"michaelrommel/nvim-silicon",
-- 	lazy = true,
-- 	cmd = "Silicon",
-- 	config = function()
-- 		require("silicon").setup({
-- 			-- Configuration here, or leave empty to use defaults
-- 			font = "SauceCodePro Nerd Font=34",
--       background = "#F6F0DC",
--       no_window_controls = true,
--       output = function()
--         return "~/Pictures/code/" .. os.date("%Y-%m-%d-%H-%M-%S") .. "_code.png"
--       end,
-- 		})
-- 	end
-- }
return {}
