-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- 关闭拼写检查（LazyVim 默认开启 spell=en，中文文档里的英文术语全被标红）
vim.opt.spell = false

-- 行间距（仅 GUI 版 nvim 生效，如 Neovide）
vim.opt.linespace = 8

-- 字体配置（仅 GUI 版 nvim 生效，如 Neovide）
vim.opt.guifont = "CaskaydiaCove Nerd Font Mono:h16"

-- 背景透明度 + 模糊（仅 Neovide 生效）
if vim.g.neovide then
  vim.g.neovide_scroll_animation_length = 0    -- 滚动动画时长（0 = 关闭，瞬切）
  vim.g.neovide_fullscreen = true              -- 启动即全屏（标题栏自动消失）
  vim.g.neovide_cursor_vfx_mode = "pixiedust"  -- 光标仙尘粒子特效 ✨
  vim.g.neovide_cursor_vfx_particle_density = 2  -- 粒子密度

  -- 一键切换光标特效：:Vfx ripple / :Vfx pixiedust / :Vfx none
  vim.api.nvim_create_user_command("Vfx", function(opts)
    vim.g.neovide_cursor_vfx_mode = opts.args
    vim.notify("✨ 光标特效: " .. (opts.args == "" and "无" or opts.args))
  end, { nargs = 1, desc = "切换 Neovide 光标特效" })
end
