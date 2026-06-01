-- ~/.config/nvim/lua/plugins/fzf.lua
-- ============================================================================
-- fzf-lua:模糊查找(文件 / 内容 / buffer / git / 快捷键 ...)
-- 两层键位:① 下面 keys 是从 nvim 调起的触发键
--          ② 进了 fzf 浮窗后的操作键见 opts.keymap(+ fzf 默认)
-- ============================================================================

return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = "FzfLua",
	keys = {
		-- 文件 / 内容
		{ "<leader>ff", "<cmd>FzfLua files<cr>", desc = "找文件" },
		{ "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "全项目搜内容" },
		{ "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "切 buffer" },
		{ "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "最近文件" },
		{ "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "搜光标下的词" },
		-- 自查类
		{ "<leader>fk", "<cmd>FzfLua keymaps<cr>", desc = "搜所有快捷键" },
		{ "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "搜帮助文档" },
		{ "<leader>f.", "<cmd>FzfLua resume<cr>", desc = "恢复上次搜索" },
		-- git
		{ "<leader>fc", "<cmd>FzfLua git_commits<cr>", desc = "git 提交历史" },
		{ "<leader>fs", "<cmd>FzfLua git_status<cr>", desc = "git status" },
	},
	opts = {
		keymap = {
			-- builtin = 用内置预览器时的窗口键(Neovim 终端层)
			builtin = {
				true, -- 继承所有默认绑定
				-- 预览滚动默认是 <S-down>/<S-up>,改成更直觉的 C-d/C-u:
				["<C-d>"] = "preview-page-down",
				["<C-u>"] = "preview-page-up",
			},
			-- fzf = 传给 fzf 进程的键(fzf 风格写法,如 ctrl-x)
			fzf = {
				true, -- 继承所有默认绑定
				["ctrl-q"] = "select-all+accept", -- 全选并发送到 quickfix
			},
		},
	},
}
