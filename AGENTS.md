# blue-dotfiles Agent 指引

本文件用于在 blue 的任一台 Mac 上接手本仓库。先核验当前机器与仓库状态，再按用户本次要求执行；阅读指引本身不触发安装、覆盖配置、提交或推送。沟通默认使用中文，称呼用户为 blue，自称队长；同时遵守宿主与本机适用的规则。

## 项目与入口

- 维护 Ghostty、VS Code、Zed、Neovim、Vim 和 Kero 的可移植配置，面向 macOS；脚本兼容系统 Bash 3.2。
- 每台电脑有自己的 Git 副本，应用配置通过软链连接本机副本，通过共享的 `origin/main` 交换修改。用户名和仓库绝对路径可以不同。
- `README.md`：软件依赖、各应用恢复方式与使用说明。
- `links.tsv`：应用、本仓库源文件、本机目标路径的唯一映射；目标路径相对于当前机器的 `$HOME`。
- `link.sh`：预览或备份并建立链接；默认只预览，不安装软件或扩展。
- `sync.sh`：`status` 只查看状态；`sync` 获取远程、提交本地受管修改、合并并正常推送，由用户或 Agent 手动触发。
- 根目录 `AGENTS.md` 随 Git 同步，不链接到用户的全局规则位置，也不把本机全局 Agent 规则复制进仓库。

## 接手时先检查

在实际仓库目录执行：

```bash
git rev-parse --show-toplevel
git status --short --branch
git remote -v
git branch -vv
./sync.sh status
./link.sh
```

核对当前机器、Git 根目录、分支、上游和真实推送目标。共享仓库为 `blue-a11y/blue-dotfiles`，日常分支为 `main`，跟踪 `origin/main`；以当前 Git 输出确认，发现指向其他仓库时先弄清归属。

保留已有的已暂存、未暂存和未跟踪工作。检查是否存在未完成的 merge、rebase、cherry-pick；检查链接是否真正指向当前副本。不要根据另一台机器的路径、备份、登录或安装记录推断本机状态。应用已连接到本副本时，切换分支、移动或删除仓库会同时影响应用配置，需先处理这些链接。

## 首次接入或迁移这台电脑

用户要求在本机启用时，按以下顺序完成：

1. 检查目标仓库是否已存在，复用归属明确的副本。新克隆默认放在 `$HOME/Documents/dev/blue/blue-dotfiles`；已存在的目录不能覆盖。可使用 `git@github.com:blue-a11y/blue-dotfiles.git`，并核验本机 Git 身份及读写认证。
2. 读取 README 的依赖说明，检查软件、字体、`code` 命令与 `macism`。安装缺失软件按用户授权处理，不能把配置已落盘当作软件已安装或服务已可用。
3. 对比 `links.tsv` 中本机已有配置与仓库配置。用户要求以仓库配置接入时，备份后应用；要求收集本机配置时，脱敏后合并。取舍不明确且会丢失有效偏好时，只澄清该差异。
4. 在仓库外建立私有备份，默认放在 `$HOME/.local/state/blue-dotfiles/backups/` 的独立目录。保存映射中所有已有文件和目录，记录原软链目标，并备份本机 `~/.vscode/argv.json`；软链指向的有效内容也要有快照。备份目录限制为当前用户访问，核对文件清单和内容校验值，避免只保存一个依赖原路径的链接。
5. 确认本地修改已妥善保存、分支及上游正确。干净的 `main` 可先 `git fetch origin main`，再 `git merge --ff-only origin/main`；不能快进时检查分歧，不强行覆盖。
6. 运行 `./link.sh` 核对目标，再运行 `./link.sh --apply`。脚本还会把原目标移动到独立备份会话；若已有对应启用授权，不重复询问常规操作。需要部分接入时可选择应用，但完整同步命令会检查映射中的全部链接。
7. 验证每个目标解析到当前副本对应源文件，再运行 `./link.sh` 确认已接入项显示 `[skip]`。按 README 恢复扩展与必要运行参数，并验证实际使用到的应用功能。
8. 已获同步授权时运行 `./sync.sh sync`，核对完成状态、备份位置与 Git 结果。仅安装或本地修改的请求，按其授权范围交付。

备份不进入 Git。恢复时先检查目标与备份，移除本次创建的软链后再还原原内容；不要删除未核对的普通文件。链接脚本失败时可能已有部分应用接入，先查明完成到哪一步再继续。

## 日常修改与双向同步

用户要求同步时，两台电脑使用相同入口：

```bash
./sync.sh sync
```

此命令包含 Git 提交和推送，执行前说明其作用并遵守当前授权。只查询状态或修改本地配置时，使用对应的只读或本地操作。阅读本文件不构成长期自动提交、推送或定时运行的授权。

日常可以在应用内或仓库内修改受管理配置。开始编辑前和编辑完成后各同步一次，可减少同时修改的冲突。同步脚本会保留 Git hooks，拒绝已有暂存内容、未完成的 Git 操作、未管理的改动、异常配置链接、常见敏感字段和固定用户名路径。

- 配置链接失效：应用可能在保存时原子替换了文件。先备份并对比该本机文件，将需要的最新修改合并进仓库，再重新接入；不要直接覆盖它或只推送仓库里的旧版本。
- 合并冲突：保留两边提交与冲突现场，检查 `git diff --name-only --diff-filter=U`。在意图明确且授权允许的范围解决，按文件暂存、正常提交，再运行同步；偏好取舍不明确时询问 blue。
- 网络或推送失败：先核验本地提交和实际远端状态；提交通常仍在本地，可恢复网络后重试。不要因回执不明重复创建提交。
- 不执行强推、`reset --hard`、`git clean`，不跳过 hooks，不为了让同步通过而删除或暂存无关文件。同步锁存在时先检查是否有任务仍在运行。

## 各应用的维护边界

- VS Code：设置、快捷键、语言、代码片段、自定义 CSS 与输入法辅助脚本走链接。`vscode/argv.json` 是模板，需要按键合并到本机文件，保留本机 `crash-reporter-id`。扩展清单可用 `code --list-extensions --show-versions | LC_ALL=C sort > vscode/extensions.txt` 更新；安装按 README 执行并核验结果。
- VSCodeVim：输入法命令通过 `/bin/sh` 展开 `$HOME` 后调用辅助脚本。保留可移植路径及 `PATH`、Apple Silicon/Intel Homebrew、`DOTFILES_MACISM_BIN` 的查找方式，不写死另一台电脑的路径。只有查询当前输入法不代表实际切换已验证。
- Zed：扩展变更同步维护 `zed/extensions.json` 与设置中的 `auto_install_extensions`。后者按当前注册表安装，不保证采集版本；模型与外部 Agent 的凭据、安装和可用性由本机单独处理。
- Neovim：配置目录整体链接；插件下载与运行缓存留在本机。维护插件定义及 `lazy-lock.json`，需要按锁恢复时使用 `:Lazy restore`。Vim 的 `vim/vimrc` 独立维护。
- Kero：`kero/app.json` 是 merge 模板，按键合并进本机 `~/Library/Application Support/Kero/app.json`，不软链。Kero 运行中会整文件重写该文件并移除它不认识的键，同步前先对比本机最新内容，把应用当前状态收进快照再提交；`selected` 引用的会话 ID 在另一台电脑上由 Kero 自行回退。`state.json`、窗口状态、会话记录、日志与内置 CLI 属于本机运行数据，不进仓库。
- Claude Code：`claude-code/CLAUDE.md` 软链到 `~/.claude/CLAUDE.md`；`claude-code/settings.json` 是 merge 模板，按键合并进本机文件，保留本机 `env.ANTHROPIC_AUTH_TOKEN` 等凭据，不软链。`~/.claude.json`、对话历史、会话数据、缓存与插件包不进仓库。cc-switch 会整文件重写 settings.json，合并后需注意被覆盖。
- 不同步账号凭据、环境密钥、登录状态、聊天与工作区数据库、缓存、已安装扩展包、软件二进制和本机备份。不要把个人服务地址、用户名路径或认证信息原样复制进公开仓库。脚本的常见 JSON/TOML 字段检查不能替代人工审阅或历史秘密审计。

## 修改仓库与验证

保持目录与脚本简单；新增受管理内容时同时检查 `links.tsv`、`sync.sh` 的 `managed()` 范围和 README，避免新增文件被同步入口拒绝。脚本修改需兼容 Bash 3.2，并用临时 HOME、本地裸仓库与独立克隆验证，不能拿真实配置或远端做破坏性测试。

脚本行为变化运行：

```bash
python3 -m unittest discover -s tests -v
bash -n link.sh sync.sh vscode/bin/vim-im-force-abc
git diff --check
```

纯文档修改检查内容、命令、引用与差异即可。应用配置变化验证对应软件实际加载；扩展安装、认证和在线服务需要各自的运行证据。

按用户授权只提交本次相关文件，保留其他改动，正常运行 hooks。推送后核验本地 `HEAD` 与真实远端 `main`，报告提交、备份和验证结果；没有接触另一台实体电脑时说明验证范围，不宣称它已启用。不要把临时提交号、某台机器的安装状态或旧备份路径写成长期规则。
