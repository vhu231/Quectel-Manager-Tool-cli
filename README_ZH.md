# 移远模块管理 CLI（Quectel Manager Tool CLI）

[English](README.md)

用于管理 Quectel（移远）蜂窝模组：只读查看 ModemManager 状态、通过 AT 口下发命令、以及短信相关操作。

---

## 功能

- 扫描并选择 Modem
- mmcli 查询与操作（信号、SIM、定位、USSD 等）
- 经 `socat` 发送 AT 命令
- 内置 AT / QCFG / QSIMCFG 目录与手册注释
- 日常快捷项（IMS/VoLTE、usbnet、重启等）
- 短信列表 / 发送 / 删除
- 中英切换（本会话有效，不落盘）
- 沉浸式 CLI（清屏 + 顶栏状态）

默认**不落盘用户数据**；仅在启动时加 `--log` 才会保存日志。

---

## 依赖

Linux（需 ModemManager）。运行时依赖：

- `bash`
- `mmcli`（ModemManager）
- `socat`
- `jq`
- `timeout` / `awk` / `sed`（通常随 coreutils 提供）

可选：`python3`（仅在重新生成目录文档时需要 `regroup_catalog.py`）。

示例（Debian/Ubuntu）：

```bash
sudo apt install modemmanager socat jq
```

---



## 快速开始

```bash
chmod +x run.sh
./run.sh
```



### 选项

```text
./run.sh [options]

  --log [PATH]   将日志持久化到 PATH。
                 省略 PATH 时：脚本同目录 ./quick-at.log。
                 不加 --log：日志只写在临时目录，退出后删除。
  --lang LANG    zh|en（仅本会话，不保存）
  -h, --help     显示帮助
```

示例：

```bash
./run.sh --lang zh
./run.sh --log
./run.sh --log /tmp/quectel-at.log --lang en
```

环境变量：

- `QUICK_AT_LANG=zh|en` — 本会话界面语言
- `QUICK_AT_LOG_MAX` — 日志轮转大小（字节，默认 `1048576`）

---



## 操作说明


| 按键              | 作用                |
| --------------- | ----------------- |
| 数字 / ↑↓ + Enter | 选择菜单项             |
| `b`             | 返回上一级             |
| `q`             | 退出                |
| Enter（Modem 页）  | 刷新列表              |
| Ctrl+C          | 取消当前等待；2 秒内再按一次退出 |


---



## 仓库内容


| 路径                   | 说明                          |
| -------------------- | --------------------------- |
| `run.sh`             | 主程序                         |
| `at_catalog.json`    | AT 命令目录与注释数据                |
| `AT_COMMANDS_ZH.md`  | 中文命令用途说明                    |
| `AT_COMMANDS_EN.md`  | 英文命令说明                      |
| `regroup_catalog.py` | 重组目录并重新生成 MD 文档             |
| `Quectel_*.pdf`      | 官方手册原文（AT / QCFG / QSIMCFG） |


手册版本：

- AT Commands Manual **V2.2**
- QCFG AT Commands Manual **V1.6**
- QSIMCFG AT Commands Manual **V1.0**

面向系列：EC2x / EG2x / EG9x / EM05 等（以手册为准）。

---



## 重新生成文档

修改 `at_catalog.json` 或分组逻辑后：

```bash
python3 regroup_catalog.py
```

会更新 `AT_COMMANDS_ZH.md` / `AT_COMMANDS_EN.md`。

---



## 安全提示

- 标有 **危险** 的项（如恢复出厂、改写 IMEI）请确认后再执行。
- AT 与 mmcli 操作会直接影响模组与网络状态；建议先在测试环境使用。
- 本工具通过系统已有的 ModemManager / 串口访问模组，请确保你有相应权限（常见为 `dialout` 组）。

---



## 许可与手册版权

脚本代码以仓库内声明为准（若未单独声明，请自行补充 `LICENSE`）。

Quectel PDF 手册版权归 **Quectel Wireless Solutions** 所有；收录仅便于对照 AT 注释，使用时请遵守厂商条款。

---



## 相关文档

- [AT_COMMANDS_ZH.md](AT_COMMANDS_ZH.md) — 中文 AT 用途
- [AT_COMMANDS_EN.md](AT_COMMANDS_EN.md) — 英文 AT 说明
- [README.md](README.md) — English README

