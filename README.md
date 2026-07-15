# Quectel Manager Tool CLI

[中文文档](README_ZH.md)

Terminal CLI for Quectel cellular modules: read-only ModemManager status, AT commands over the serial AT port, and SMS helpers.

---

## Features

- Scan and select modems
- mmcli query & actions (signal, SIM, location, USSD, …)
- Send AT commands via `socat`
- Built-in AT / QCFG / QSIMCFG catalog with manual notes
- Daily quick presets (IMS/VoLTE, usbnet, reboot, …)
- SMS list / send / delete
- Immersive CLI (clear screen + sticky header)

By default **no user data is written to disk**; pass `--log` only if you want persistent logs.

---



## Dependencies

Linux with ModemManager. Runtime deps:

- `bash`
- `mmcli` (ModemManager)
- `socat`
- `jq`
- `timeout` / `awk` / `sed` (usually from coreutils)

Optional: `python3` (only for regenerating catalog docs with `regroup_catalog.py`).

Example (Debian/Ubuntu):

```bash
sudo apt install modemmanager socat jq
```

---



## Quick start

```bash
chmod +x run.sh
./run.sh
```



### Options

```text
./run.sh [options]

  --log [PATH]   Persist log to PATH.
                 If PATH omitted: ./quick-at.log next to the script.
                 Without --log: log only in a temp dir (deleted on exit).
  --lang LANG    UI language for this session (not saved)
  -h, --help     Show help
```

Examples:

```bash
./run.sh
./run.sh --log
./run.sh --log /tmp/quectel-at.log
```

Environment:

- `QUICK_AT_LANG` — session UI language
- `QUICK_AT_LOG_MAX` — log rotate size in bytes (default `1048576`)

---



## Controls


| Key                 | Action                                             |
| ------------------- | -------------------------------------------------- |
| Number / ↑↓ + Enter | Select menu item                                   |
| `b`                 | Back                                               |
| `q`                 | Quit                                               |
| Enter (modem page)  | Refresh modem list                                 |
| Ctrl+C              | Cancel current wait; press again within 2s to quit |


---



## Repository layout


| Path                 | Description                            |
| -------------------- | -------------------------------------- |
| `run.sh`             | Main CLI                               |
| `at_catalog.json`    | Command catalog and notes              |
| `AT_COMMANDS_ZH.md`  | Chinese command notes                  |
| `AT_COMMANDS_EN.md`  | English command notes                  |
| `regroup_catalog.py` | Regroup catalog and regenerate MD docs |
| `Quectel_*.pdf`      | Official manuals (AT / QCFG / QSIMCFG) |


Manual versions:

- AT Commands Manual **V2.2**
- QCFG AT Commands Manual **V1.6**
- QSIMCFG AT Commands Manual **V1.0**

Target series: EC2x / EG2x / EG9x / EM05 and related (per manuals).

---



## Regenerate docs

After editing `at_catalog.json` or grouping logic:

```bash
python3 regroup_catalog.py
```

This updates `AT_COMMANDS_ZH.md` / `AT_COMMANDS_EN.md`.

---



## Safety

- Items marked **DANGER** (factory reset, IMEI write, etc.) require confirmation.
- AT and mmcli calls affect the module and network — test carefully first.
- You typically need membership in the `dialout` group (or equivalent) for serial AT ports.

---



## License & manuals

This project’s scripts and docs are released under the [MIT License](LICENSE).

Quectel PDF manuals are copyright **Quectel Wireless Solutions**; included for AT annotation reference only. Follow the vendor terms when using them.

---



## Related docs

- [AT_COMMANDS_EN.md](AT_COMMANDS_EN.md) — English AT notes
- [AT_COMMANDS_ZH.md](AT_COMMANDS_ZH.md) — Chinese AT notes
- [README_ZH.md](README_ZH.md) — Chinese README

