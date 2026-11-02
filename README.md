# blue-dotfiles

blue 的 macOS 编辑器与终端配置。维护 Ghostty、VS Code、Zed、Neovim 和 Vim，两台电脑通过各自的软链和同一 Git 分支双向同步。

Agent 接手时先读 [`AGENTS.md`](AGENTS.md)，其中约定了本机状态检查、首次备份接入、双向同步和故障恢复流程。

## 同步范围

| 目录 | 内容 |
| --- | --- |
| `ghostty/` | Ghostty 主配置：Dracula、字体、光标、透明度、窗口和滚动设置 |
| `vscode/` | 自定义 CSS、输入法辅助脚本、运行参数模板；设置、快捷键、语言、代码片段与扩展由 VS Code 云端同步（Settings Sync）接管，不进仓库 |
| `zed/` | 设置、快捷键、3 份代码片段、3 个本地主题、10 个扩展及版本 |
| `nvim/` | 当前 LazyVim 配置、插件定义、快捷键、Neovide 设置和 `lazy-lock.json` |
| `vim/` | 独立 Vim 配置 |
| `kero/` | Kero 终端的偏好基准 `app.json`（merge 模板，不软链）；`state.json`、窗口状态、会话记录、日志和内置 CLI 属于本机运行数据，不进入仓库 |
| `claude-code/` | Claude Code 全局规则 `CLAUDE.md`（软链）与偏好基准 `settings.json`（merge 模板，不软链）；API token、`~/.claude.json`、对话历史、会话状态、缓存和插件包不进入仓库 |

配置是个人偏好的快照；不会为了更新说明而主动升级编辑器、修改主题或升级插件。

账号凭据、登录状态、聊天与工作区数据库、缓存、安装后的扩展包、旧配置备份不进入仓库。VS Code 当前没有额外用户 Profile，MCP 文件为空，因此没有额外的有效配置可收集。Zed 的提示词数据库属于本地数据，未作为代码片段同步。

## 链接配置

```bash
git clone https://github.com/blue-a11y/blue-dotfiles.git
cd blue-dotfiles

# 只预览，不修改本机文件。
./link.sh

# 也可以只处理一部分应用。
./link.sh vscode zed

# 确认预览后，备份已有目标并创建软链。
./link.sh --apply
# ./link.sh --apply ghostty vscode zed nvim vim
```

支持 macOS 自带的 Bash 3.2，无额外脚本依赖。`neovim` 是 `nvim` 的别名。`--home /absolute/path` 可将目标指向测试目录；默认目标为当前用户的 `$HOME`。

[`links.tsv`](links.tsv) 是唯一的链接映射。每次执行会先检查全部选中源文件；已有的正确软链会跳过（包括通过父目录软链到位的情况）。脚本拒绝会移动或改写仓库源文件的目标；普通文件、目录、硬链接和旧软链会移动到独立备份目录，再创建新链接：

```text
~/.local/state/blue-dotfiles/backups/<timestamp>.<random>/
```

备份保留原来的相对路径，重复执行不会覆盖旧备份。如需撤回，先关闭对应应用，核对并删除本次创建的目标软链，再把备份中的原文件或目录移回原位置。发生错误时先查看已输出的链接与备份路径；脚本不会自动撤回前面已经完成的链接。

链接后，在应用内修改受管理的配置也会修改仓库。提交前检查差异和私密信息；`link.sh` 本身不执行 Git 提交或推送。

## 两台电脑双向同步

每台电脑各自克隆仓库，应用配置链接到各自的本地副本。两边跟踪同一个远程分支，例如 `origin/main`。仓库在两台电脑上的绝对路径、用户名可以不同；创建软链时使用各自的路径。

首次使用时，先将重建后的仓库发布到共享分支，再在每台电脑的仓库目录运行：

```bash
./link.sh           # 核对目标
./link.sh --apply   # 备份原配置并接入本机应用
./sync.sh status    # 检查分支和本地改动
```

日常两边都用同一个命令：

```bash
./sync.sh sync
```

命令会检查本地状态，获取当前跟踪的远程分支，把本机受管理配置的修改提交到 Git，合并远程更新，最后正常推送。获取远程后和推送前会再次核验配置链接与当前文件。两台电脑的流程对称：在 A 修改后同步，在 B 同步即可收到；B 的修改也按同样方式传回 A。开始编辑前和编辑完成后各执行一次，可减少两边同时修改同一内容的机会。

同步由手动运行命令触发。`./sync.sh` 不带参数默认查看状态，只有明确使用 `sync` 才会提交、合并与推送。它保留 Git hooks，不使用强推，也不重置或清理工作区。

遇到以下情况会停止并保留现场：

- 已暂存但未提交的修改、未完成的 merge/rebase，或分支没有正确的远程跟踪关系。
- 本机配置没有接入这份仓库，或应用保存时替换了文件软链。先对比并保留本机文件中的新修改，再重新建立链接；同步不会静默忽略或覆盖它。
- 同步范围外的新增或修改文件，常见凭据字段，或写死用户名的配置路径。私密字段检查覆盖当前受管理配置，包括已在本机提交的当前文件；只显示文件名，不输出值。这是常见 JSON/TOML 字段检查，不能替代提交前审阅，也不审计既有 Git 历史。
- 两台电脑的修改发生合并冲突。两边提交和冲突文件都会保留；手动解决后 `git add`、`git commit`，再运行同步。
- 网络或推送失败。获取远程失败时，本地修改和暂存区保持原样；推送失败时，本地提交保留，可恢复网络后重试。

安装软件、字体、登录账号与恢复扩展仍按下方说明在各台电脑完成。新增或卸载扩展后，需要显式更新扩展清单；同步配置不会复制已安装的扩展程序或认证数据。

## VS Code 恢复

VS Code 自带云端同步（Settings Sync）：设置、快捷键、语言、代码片段与扩展由它接管，不进仓库。新机器登录同一账号并开启同步后，这些内容自动恢复。

链接只覆盖云同步覆盖不到的两项：`~/.vscode/custom.css` 和 `~/.local/bin/vim-im-force-abc`。

另外两项需要在恢复时处理：

- `vscode/argv.json` 是可移植运行参数模板。将其键合并进本机 `~/.vscode/argv.json`，保留本机已有的 `crash-reporter-id`；该模板不参与软链。
- 安装 Custom CSS 扩展后，在 VS Code 命令面板执行 `Reload Custom CSS and JS` 并按提示重启。VS Code 更新后可能需要重新启用；本仓库不修改应用安装文件。[扩展说明](https://github.com/be5invis/vscode-custom-css)

CSS 路径使用扩展支持的 `${userHome}`。输入法切换命令先调用 `/bin/sh`，再展开 `$HOME` 找到辅助脚本，兼容 VSCodeVim 对原始可执行路径的检查。辅助脚本保持现有行为：进入或离开 Vim 插入模式时切换到 ABC 输入法。

## Zed 整套恢复

链接覆盖 `~/.config/zed/` 下的设置、快捷键、代码片段和自定义主题目录。`settings.json` 的 `auto_install_extensions` 记录全部 10 个已安装扩展，启动 Zed 后由其按当前扩展注册表安装。[官方说明](https://zed.dev/docs/reference/all-settings#auto-install-extensions)

`zed/extensions.json` 另行保留采集时的版本与来源，供核对；自动安装不保证恢复相同版本。需要特定版本时，在 Zed 扩展面板选择相应版本。

保留现有的 MiniMax、Ollama 与外部 Agent 定义；认证信息仍由本机保存。使用这些功能时，需要相应服务和 Agent 已可用，配置文件本身不代表服务已接通。

## Neovim 与 Vim

Neovim 整个配置目录链接到 `~/.config/nvim`，插件代码与下载缓存由 lazy.nvim 管理，不进入仓库。`lazy-lock.json` 保留当前插件提交；需要按锁文件恢复时，在 Neovim 中使用 `:Lazy restore`。

Neovim 的 `LICENSE` 随原配置保留。`vim/vimrc` 单独链接到 `~/.vimrc`，不依赖 Neovim。

## Claude Code

`claude-code/CLAUDE.md` 软链到 `~/.claude/CLAUDE.md`，是所有项目共享的全局规则；项目级规则放在各项目根目录，不进仓库。

`claude-code/settings.json` 是偏好基准模板，**不参与软链**。接入新机器时将其各键合并进本机 `~/.claude/settings.json`：保留本机已有的 `env.ANTHROPIC_AUTH_TOKEN` 等凭据字段，其余偏好（模型路由、语言、视图、权限模式等）以模板为准。模板不含任何 API token；凭据由 cc-switch 等本机工具单独管理，注意 cc-switch 重写 settings.json 时可能覆盖合并结果。`~/.claude.json`、`history.jsonl`、会话与项目数据、缓存、插件包和 `settings.local.json` 属于本机状态，不同步。

## Kero

`kero/app.json` 是偏好基准模板，**不参与软链**。接入新机器时将其各键合并进本机 `~/Library/Application Support/Kero/app.json`，保留本机会话引用。Kero 运行中会整文件重写该文件（会移除它不认识的键），同步前先以本机最新内容为准收进快照。`state.json`、窗口状态、会话记录、日志与内置 CLI 属于本机运行数据，不进仓库。

## 本机依赖

- Ghostty、VS Code、Zed、Neovim、Vim 需分别安装。
- 现有字体为 CaskaydiaCove Nerd Font，Ghostty、Neovide 和自定义 CSS 使用 Mono 变体。
- VSCodeVim 输入法功能依赖 `macism`。辅助脚本先从 `PATH` 查找，再尝试 Apple Silicon 与 Intel 的 Homebrew 路径；也可用本机环境变量 `DOTFILES_MACISM_BIN` 指定安装位置。
- Neovide 相关设置与快捷键随 Neovim 保存；使用时另需 Neovide。
- Zed 的模型、补全服务与外部 Agent 属于可选运行依赖，不自动安装。

## 日常更新与检查

应用配置链接后可直接在应用内维护。VS Code 的设置、快捷键、代码片段与扩展变更由其云端同步接管，不需要改仓库；Zed 扩展变更时，同时更新 `zed/extensions.json` 与 `settings.json` 的 `auto_install_extensions`；Neovim 的插件变更随 `lazy-lock.json` 记录。

```bash
python3 -m unittest discover -s tests -v
bash -n link.sh
bash -n sync.sh
./link.sh
./sync.sh status
git diff --check
```

测试在临时目录运行真实链接脚本，并用本地裸仓库和两个独立克隆验证双向同步、并发修改、冲突与失败恢复，不连接真实 GitHub 仓库，也不改动本机应用配置。
