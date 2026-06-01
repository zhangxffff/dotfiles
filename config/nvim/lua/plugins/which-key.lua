-- ~/.config/nvim/lua/plugins/which-key.lua
-- ============================================================================
-- which-key:按下 <leader> 停顿后弹出可用键位提示
-- 把各组前缀命名好,弹出来按组归类,一眼看清
-- ============================================================================

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		-- preset 控制外观:classic / modern / helix,看你喜好
		preset = "modern",
		-- 弹出延迟(ms);觉得太快打扰可调大,如 500
		delay = 300,
		spec = {
			-- 给各组前缀起名(对应 dev.lua / git.lua 里的键位)
			{ "<leader>h", group = "Git Hunk" }, -- gitsigns:stage/reset/preview/blame
			{ "<leader>g", group = "Git Diff" }, -- diffview:diff/历史
			{ "<leader>r", group = "Rust" }, -- rustaceanvim:runnables/宏
			{ "<leader>t", group = "Toggle" }, -- inlay hint 等开关
			{ "<leader>c", group = "Code" }, -- code action 等
			-- 后面装了别的再加,比如:
			-- { "<leader>f", group = "Find" },    -- fzf-lua
			-- { "<leader>a", group = "Harpoon/Grapple" },
		},
	},
	keys = {
		-- 手动唤出:显示所有键位(含非 leader 的)
		{
			"<leader>?",
			function()
				require("which-key").show({ global = true })
			end,
			desc = "显示所有 buffer 键位",
		},
	},
}
