# Quectel Manager Tool CLI / 移远模块管理 CLI

中英双语终端工具，用于管理 Quectel（移远）蜂窝模组：只读查看 ModemManager 状态、通过 AT 口下发命令、以及短信相关操作。

A bilingual (zh/en) terminal CLI for Quectel cellular modules: read-only ModemManager status, AT commands over the serial AT port, and SMS helpers.

---

## 功能 / Features

| 中文 | English |
|------|---------|
| 扫描并选择 Modem | Scan and select modems |
| mmcli 查询与操作（信号、SIM、定位、USSD 等） | mmcli query & actions (signal, SIM, location, USSD, …) |
| 经 `socat` 发送 AT 命令 | Send AT commands via `socat` |
| 内置 AT / QCFG / QSIMCFG 目录与手册注释 | Built-in AT / QCFG / QSIMCFG catalog with manual notes |
| 日常快捷项（IMS/VoLTE、usbnet、重启等） | Daily quick presets (IMS/VoLTE, usbnet, reboot, …) |
| 短信列表 / 发送 / 删除 | SMS list / send / delete |
| 中英切换（本会话有效，不落盘） | zh/en toggle (session only, not persisted) |
| 沉浸式 CLI（清屏 + 顶栏状态） | Immersive CLI (clear screen + sticky header) |

默认**不落盘用户数据**；仅在启动时加 `--log` 才会保存日志。

By default **no user data is written to disk**; pass `--log` only if you want persistent logs.

---

## 依赖 / Dependencies

Linux（需 ModemManager）。运行时依赖：

Linux (ModemManager required). Runtime deps:

- `bash`
- `mmcli`（ModemManager）
- `socat`
- `jq`
- `timeout` / `awk` / `sed`（通常随 coreutils 提供）

可选：`python3`（仅在重新生成目录文档时需要 `regroup_catalog.py`）。

Optional: `python3` (only for regenerating catalog docs with `regroup_catalog.py`).

示例（Debian/Ubuntu）：

```bash
sudo apt install modemmanager socat jq
```

---

## 快速开始 / Quick start

```bash
chmod +x run.sh
./run.sh
```

### 选项 / Options

```text
./run.sh [options]

  --log [PATH]   Persist log to PATH.
                 If PATH omitted: ./quick-at.log next to the script.
                 Without --log: log only in a temp dir (deleted on exit).
  --lang LANG    zh|en (session only, not saved)
  -h, --help     Show help
```

示例 / Examples:

```bash
./run.sh --lang en
./run.sh --log
./run.sh --log /tmp/quectel-at.log --lang zh
```

环境变量 / Environment:

- `QUICK_AT_LANG=zh|en` — 本会话界面语言 / session UI language
- `QUICK_AT_LOG_MAX` — 日志轮转大小（字节，默认 1048576） / log rotate size in bytes

---

## 操作说明 / Controls

| 按键 | 中文 | English |
|------|------|---------|
| 数字 / ↑↓ + Enter | 选择菜单项 | Select menu item |
| `b` | 返回上一级 | Back |
| `q` | 退出 | Quit |
| Enter（Modem 页） | 刷新列表 | Refresh modem list |
| Ctrl+C | 取消当前等待；2 秒内再按一次退出 | Cancel current wait; press again within 2s to quit |

---

## 仓库内容 / Repository layout

| 路径 | 说明 |
|------|------|
| `run.sh` | 主程序 / Main CLI |
| `at_catalog.json` | AT 命令目录与注释数据 / Command catalog |
| `AT_COMMANDS_ZH.md` | 中文命令用途说明 |
| `AT_COMMANDS_EN.md` | English command notes |
| `regroup_catalog.py` | 重组目录并重新生成 MD 文档 |
| `Quectel_*.pdf` | 官方手册原文（AT / QCFG / QSIMCFG） |

手册版本：

- AT Commands Manual **V2.2**
- QCFG AT Commands Manual **V1.6**
- QSIMCFG AT Commands Manual **V1.0**

面向系列：EC2x / EG2x / EG9x / EM05 等（以手册为准）。

---

## 重新生成文档 / Regenerate docs

修改 `at_catalog.json` 或分组逻辑后：

```bash
python3 regroup_catalog.py
```

会更新 `AT_COMMANDS_ZH.md` / `AT_COMMANDS_EN.md`。

---

## 安全提示 / Safety

- 标有 **危险 / DANGER** 的项（如恢复出厂、改写 IMEI）请确认后再执行。
- AT 与 mmcli 操作会直接影响模组与网络状态；建议先在测试环境使用。
- 本工具通过系统已有的 ModemManager / 串口访问模组，请确保你有相应权限（常见为 `dialout` 组）。

Dangerous actions (factory reset, IMEI write, etc.) require confirmation. AT/mmcli calls affect the module and network — use carefully. You typically need membership in the `dialout` group (or equivalent) for serial AT ports.

---

## 许可与手册版权 / License & manuals

脚本代码以仓库内声明为准（若未单独声明，默认仅供个人/内部使用，请自行补充 LICENSE）。

Quectel PDF 手册版权归 **Quectel Wireless Solutions** 所有；收录仅便于对照 AT 注释，使用时请遵守厂商条款。

Script license: add a `LICENSE` if you redistribute. Quectel PDF manuals are copyright **Quectel Wireless Solutions**; included for AT annotation reference only.

---

## 相关文档 / Related docs

- [AT_COMMANDS_ZH.md](AT_COMMANDS_ZH.md) — 中文 AT 用途
- [AT_COMMANDS_EN.md](AT_COMMANDS_EN.md) — English AT notes
