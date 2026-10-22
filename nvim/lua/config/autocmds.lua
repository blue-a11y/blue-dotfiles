-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- 覆盖 LazyVim wrap_spell：text 类文件保留自动换行，但关掉拼写检查
-- （spell=en 会把中文文档里的英文术语全标红；本文件在 VeryLazy 加载，
--  晚于 LazyVim 的 autocmd 注册，同事件后注册者后执行，能压住上面的 spell=true）
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.spell = false
  end,
})
