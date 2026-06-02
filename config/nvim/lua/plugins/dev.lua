-- ~/.config/nvim/lua/plugins/dev.lua
-- ============================================================================
-- C++ / Rust / Python / Shell 开发栈(Neovim 原生 LSP 路线)
--
-- 前提:
--   * Neovim >= 0.11.3(用到 vim.lsp.config / vim.lsp.enable 新 API);0.12 更佳
--   * 必须先禁用/卸载 coc.nvim,否则补全和 LSP 会双开打架
--   * lazy.nvim 的 import 模式("plugins"),把此文件放到 lua/plugins/ 下即可
--
-- 版本兼容(rustaceanvim,见下方):
--   * Neovim 0.12+ : version = "^9"
--   * Neovim 0.11  : version = "8.0.5"(锁死,新主线已不支持 0.11)
--   先 `nvim --version` 确认你是哪个,改下面 rustaceanvim 的 version 字段
--
-- 网络:blink 的 Rust 二进制、mason 工具都从 GitHub 下载。
--   * 网络通畅走预编译即可(默认);若 blink 下载失败,见下方 spec 里的本地编译注释
--   * mason 工具若偶尔下不动,重试或手动把二进制塞进 PATH
--
-- 外部二进制(mason 会自动装大部分,见下方 mason-tool-installer):
--   C++   : clangd, clang-format          (建议用系统 LLVM 的版本而非 mason)
--   Rust  : rust-analyzer, rustfmt        (强烈建议 `rustup component add rust-analyzer`,跟工具链对齐)
--   Python: basedpyright, ruff
--   Shell : bash-language-server, shellcheck, shfmt
--   Lua   : lua-language-server, stylua   (维护 nvim 配置本身)
--
-- 拆分建议:这一份是单文件便于分享;你可以按 "====" 注释块拆成
-- lsp.lua / completion.lua / rust.lua / treesitter.lua / format.lua。
-- ============================================================================

return {
  -- ==========================================================================
  -- 补全引擎:blink.cmp(锁 v1,V2 还在 breaking 阶段)
  -- ==========================================================================
  {
    "saghen/blink.cmp",
    version = "1.*",
    -- 默认走预编译二进制(网络通畅最省事)。万一下载失败,取消下面注释用本地编译:
    -- build = "cargo build --release",  -- 需 Rust 工具链
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
      "giuxtaposition/blink-cmp-copilot", -- Copilot as a blink source (see plugins/copilot.lua)
    },
    opts = {
      -- "default" = C-n/C-p 选,C-y 确认。Tab 让给 Copilot(见 plugins/copilot.lua
      -- 的智能 Tab),所以这里把 blink 的 Tab/S-Tab(默认是 snippet 跳转)清空,
      -- 避免两边抢同一个键。
      keymap = {
        preset = "default",
        ["<Tab>"] = {},
        ["<S-Tab>"] = {},
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        -- blink 的 ghost text 关闭:行内 ghost text 由 copilot.lua 的 suggestion
        -- 模式负责(<M-l> 接受),避免两个 ghost text 打架。
        ghost_text = { enabled = false },
      },
      sources = {
        -- copilot 作为补全源出现在菜单里,和 LSP 一起选
        default = { "copilot", "lsp", "path", "snippets", "buffer" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-cmp-copilot",
            score_offset = 100, -- 让 Copilot 项靠前
            async = true,
          },
        },
      },
      -- Rust 模糊匹配,缺二进制时回退 Lua 并告警
      fuzzy = { implementation = "prefer_rust_with_warning" },
      signature = { enabled = true },
    },
  },

  -- ==========================================================================
  -- LSP:mason 管二进制 + nvim-lspconfig 提供 server 配置 + 原生 0.11 API 启用
  -- ==========================================================================
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", opts = {} }, -- 原 williamboman/mason.nvim
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      -- 自动安装工具(Rust 工具链刻意不放这里,用 rustup 的版本)
      require("mason-tool-installer").setup({
        ensure_installed = {
          "clangd",
          "clang-format",
          "basedpyright",
          "ruff",
          "bash-language-server",
          "shellcheck",
          "shfmt",
          "lua-language-server",
          "stylua",
        },
      })

      -- 把 blink 的补全能力注入所有 server
      local caps = require("blink.cmp").get_lsp_capabilities()
      vim.lsp.config("*", { capabilities = caps })

      -- ---------- C++ ----------
      -- 大型项目要点:background-index + clang-tidy;需要项目根有 compile_commands.json
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu", -- 自动插 #include;若它在大项目乱加头,改 never 手动管
          "--completion-style=detailed",
          "--function-arg-placeholders",
          "--fallback-style=llvm",
          "-j=48", -- 索引并行度;你那台 EPYC 可以往上调
        },
        init_options = {
          usePlaceholders = true,
          completeUnimported = true,
          clangdFileStatus = true,
        },
      })

      -- ---------- Python ----------
      -- 分工:basedpyright 管类型/跳转/补全,ruff 管 lint + format + import 整理
      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            disableOrganizeImports = true, -- 交给 ruff
            analysis = {
              -- basedpyright 默认 "all" 极吵,standard 更适合日常
              typeCheckingMode = "standard",
              autoImportCompletions = true,
              diagnosticMode = "openFilesOnly",
            },
          },
        },
      })
      vim.lsp.config("ruff", {
        -- 用 ruff 内置的 `ruff server`,不再需要独立的 ruff-lsp
        -- 关掉 hover,避免和 basedpyright 的悬浮信息重复
        on_attach = function(client)
          client.server_capabilities.hoverProvider = false
        end,
      })

      -- ---------- Shell ----------
      -- bash-language-server 会自动调用 PATH 里的 shellcheck 做诊断
      vim.lsp.config("bashls", {
        filetypes = { "sh", "bash" },
      })

      -- ---------- Lua(维护配置用) ----------
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      -- 注意:这里不 enable rust_analyzer,Rust 交给 rustaceanvim 独占接管
      vim.lsp.enable({ "clangd", "basedpyright", "ruff", "bashls", "lua_ls" })

      -- ---------- LSP 按键(buffer-local,attach 时绑定) ----------
      -- 0.11 已内置:K(hover) grn(rename) gra(code action) grr(refs)
      --             gri(impl) gO(symbols) ]d/[d(诊断跳转) C-s(insert 签名)
      -- 这里补充常用的 gd / gD / 以及 inlay hint / format 开关
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local buf = ev.buf
          local map = function(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = buf, desc = "LSP: " .. desc })
          end
          -- 若装了 fzf-lua,可把下面两行换成 require("fzf-lua").lsp_definitions / lsp_references
          map("gd", vim.lsp.buf.definition, "定义")
          map("gD", vim.lsp.buf.declaration, "声明")
          map("gy", vim.lsp.buf.type_definition, "类型定义")

          -- inlay hints 开关(C++/Rust 看类型很有用)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = buf })
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
            end, "切换 inlay hint")
          end
        end,
      })

      -- 诊断显示:行内虚拟文本 + 符号
      vim.diagnostic.config({
        virtual_text = { spacing = 2, prefix = "●" },
        severity_sort = true,
        float = { border = "rounded", source = true },
      })
    end,
  },

  -- ==========================================================================
  -- Rust:rustaceanvim(自带 rust-analyzer 编排、宏展开、runnables、DAP 桥接)
  -- 不要再用 lspconfig enable rust_analyzer,会双开
  -- ==========================================================================
  {
    "mrcjkb/rustaceanvim",
    -- 按你的 nvim 版本改:0.12+ 用 "^9";0.11 用 "8.0.5"
    version = "^9",
    lazy = false, -- 插件自己做 ft 触发,不要再包 lazy
    dependencies = { "saghen/blink.cmp" }, -- 为下面取 capabilities,保证加载顺序
    init = function()
      vim.g.rustaceanvim = {
        server = {
          -- 关键:rustaceanvim 不走 vim.lsp.config("*"),blink 能力不会自动注入,
          -- 必须在这里单独给,否则 Rust 补全缺自动导入/snippet 等增强
          capabilities = require("blink.cmp").get_lsp_capabilities(),
          on_attach = function(_, bufnr)
            local map = function(keys, fn, desc)
              vim.keymap.set("n", keys, fn, { buffer = bufnr, desc = "Rust: " .. desc })
            end
            -- rustaceanvim 的代码动作菜单(比通用 code action 更全)
            map("<leader>ca", function() vim.cmd.RustLsp("codeAction") end, "代码动作")
            map("<leader>rr", function() vim.cmd.RustLsp("runnables") end, "runnables")
            map("<leader>rm", function() vim.cmd.RustLsp({ "expandMacro" }) end, "展开宏")
            map("K", function() vim.cmd.RustLsp({ "hover", "actions" }) end, "hover")
          end,
          default_settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true, buildScripts = { enable = true } },
              checkOnSave = true,
              check = { command = "clippy" }, -- 保存时跑 clippy
              procMacro = { enable = true },
              inlayHints = { lifetimeElisionHints = { enable = "skip_trivial" } },
            },
          },
        },
      }
    end,
  },

  -- ==========================================================================
  -- Treesitter:语法高亮 / 缩进
  -- main 分支(为 Neovim 0.11+/0.12 重写;master 已冻结、在 0.12 上会报
  -- "attempt to call method 'range'")。API 与 master 不同:用 install() 装
  -- parser,高亮由 Neovim 的 vim.treesitter.start() 提供。缩进交给 Neovim 内置的
  -- 按文件类型缩进(main 的 treesitter indentexpr 仍实验、换行会缩进错位)。
  -- ==========================================================================
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false, -- main 分支推荐随启动加载
    config = function()
      local langs = {
        "c", "cpp", "rust", "python", "bash",
        "lua", "vim", "vimdoc", "toml", "yaml", "json", "markdown", "markdown_inline", "cmake",
      }
      -- 安装/更新 parser(异步;首次会现编译,需要 C 编译器)。守卫:从 master
      -- 切到 main 的第一次启动,lazy 还没 checkout main,旧 master 没有 install(),
      -- 跳过以免 config 报错——`:Lazy sync` 切到 main 后重启即生效。
      local nts = require("nvim-treesitter")
      if type(nts.install) == "function" then
        nts.install(langs)
      end

      -- parser 名与 filetype 不一致的注册映射,让 vim.treesitter.start() 能识别
      vim.treesitter.language.register("bash", { "sh" })
      vim.treesitter.language.register("vimdoc", { "help" })

      -- 开高亮(由 Neovim 提供);缩进不设 treesitter indentexpr,沿用内置 ftplugin
      -- 缩进 + autoindent(options.lua),换行缩进更准。
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },

  -- ==========================================================================
  -- 格式化:conform.nvim(保存时格式化,无对应 formatter 则回退 LSP)
  -- ==========================================================================
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        c = { "clang-format" },
        cpp = { "clang-format" },
        rust = { "rustfmt" },
        python = { "ruff_organize_imports", "ruff_format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        lua = { "stylua" },
      },
      format_on_save = {
        timeout_ms = 2000,
        lsp_format = "fallback",
      },
      formatters = {
        shfmt = { prepend_args = { "-i", "2", "-ci" } }, -- 2 空格缩进 + case 缩进
      },
    },
  },
}
