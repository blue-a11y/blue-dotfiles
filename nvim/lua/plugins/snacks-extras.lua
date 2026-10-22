-- snacks 配置
return {
  {
    "folke/snacks.nvim",
    -- ⚠️ lazy 的 opts 函数返回值是「整体替换」不是 merge，
    -- 必须修改传入的 opts 并 return，否则会丢掉 LazyVim 的全部 snacks 配置
    opts = function(_, opts)
      -- 仓库根目录；各仓库的 .worktrees 被自己的 .gitignore 忽略，
      -- fd 尊重 gitignore 扫不到，需显式收集后作为独立根传入
      local dev = {
        "~/Documents/dev/bytedance",
        "~/Documents/dev/blue",
      }
      for _, base in ipairs { "~/Documents/dev/bytedance", "~/Documents/dev/blue" } do
        for _, dir in ipairs(vim.fn.glob(vim.fn.expand(base) .. "/*/.worktrees", false, true)) do
          dev[#dev + 1] = dir
        end
      end
      opts.picker = opts.picker or {}
      opts.picker.layout = opts.picker.layout or {}
      -- 关闭 j/k 循环滚动（到顶/底不再跳到另一端）
      opts.picker.layout.cycle = false
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.projects = opts.picker.sources.projects or {}
      -- 扫描这些目录下的子文件夹（自动识别 git 项目）
      opts.picker.sources.projects.dev = dev
      return opts
    end,
  },

  -- 文件树自动刷新：Neovide 窗口获得焦点时刷新 explorer
  {
    "folke/snacks.nvim",
    opts = function()
      vim.api.nvim_create_autocmd("FocusGained", {
        group = vim.api.nvim_create_augroup("explorer_autorefresh", { clear = true }),
        callback = function()
          local pickers = Snacks.picker.get({ source = "explorer", tab = false })
          for _, picker in ipairs(pickers) do
            if picker and not picker.closed then
              picker:find()
            end
          end
        end,
      })
    end,
  },

  -- 确保 Mason 自动安装前端格式化/检查工具
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "prettierd", -- 代码格式化
        "eslint_d", -- ESLint 诊断
      },
    },
  },
}
