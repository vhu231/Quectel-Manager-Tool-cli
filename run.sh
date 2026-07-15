#!/usr/bin/env bash
# Quectel module manager CLI: mmcli read-only, AT via socat, SMS via mmcli.
# Bilingual zh/en. Catalog notes via jq.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_JSON="${SCRIPT_DIR}/at_catalog.json"
# Language: in-memory only. Log: session temp unless --log is passed.
LOG_MAX_BYTES="${QUICK_AT_LOG_MAX:-1048576}"
PERSIST_LOG=0

TMPDIR_ROOT="${TMPDIR:-/tmp}"
WORKDIR="$(mktemp -d "${TMPDIR_ROOT}/quick-at.XXXXXX")"
RESP_FILE="${WORKDIR}/at_resp.txt"
LOG_FILE="${WORKDIR}/session.log"
SELECTED_MODEM_ID=""
SELECTED_PORT=""
SELECTED_LABEL=""
MODEM_PORTS=()
RESOLVED_CMD=""
SPIN_PID=""
UI_LANG="zh"
INTERRUPTED=0
LAST_INT_TS=0
# After AT result: 0=continue, 1=back one level, 2=quit app
NAV_AFTER_AT=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

  --log [PATH]   Persist log to PATH.
                 If PATH omitted: ${SCRIPT_DIR}/quick-at.log
                 Without --log: log only in temp dir (deleted on exit).
  --lang LANG    zh|en (session only, not saved)
  -h, --help     Show this help

EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --log)
        PERSIST_LOG=1
        if [[ $# -ge 2 && "$2" != -* ]]; then
          LOG_FILE="$2"
          shift 2
        else
          LOG_FILE="${SCRIPT_DIR}/quick-at.log"
          shift
        fi
        ;;
      --log=*)
        PERSIST_LOG=1
        LOG_FILE="${1#--log=}"
        [[ -n "$LOG_FILE" ]] || LOG_FILE="${SCRIPT_DIR}/quick-at.log"
        shift
        ;;
      --lang)
        [[ $# -ge 2 ]] || { echo "missing --lang value" >&2; exit 2; }
        QUICK_AT_LANG="$2"
        shift 2
        ;;
      --lang=*)
        QUICK_AT_LANG="${1#--lang=}"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "unknown option: $1" >&2
        usage
        exit 2
        ;;
    esac
  done
}

cleanup() {
  spin_stop 2>/dev/null || true
  rm -rf "${WORKDIR}" 2>/dev/null || true
}

on_interrupt() {
  # Cancel current wait/op; double Ctrl+C within 2s exits the app.
  spin_stop 2>/dev/null || true
  printf '\r\033[K' 2>/dev/null || true
  INTERRUPTED=1
  local now
  now="$(date +%s 2>/dev/null || echo 0)"
  if [[ "${LAST_INT_TS:-0}" -gt 0 ]] && (( now - LAST_INT_TS <= 2 )); then
    echo
    if declare -F msg >/dev/null 2>&1; then
      echo "  $(msg bye)"
    else
      echo "  Bye"
    fi
    exit 130
  fi
  LAST_INT_TS=$now
  echo
  if declare -F msg >/dev/null 2>&1; then
    echo "  ^C — $(msg int_hint)"
  else
    echo "  ^C — cancelled (Ctrl+C again to quit)"
  fi
}

trap cleanup EXIT
# INT/TERM installed in main() after msg() exists

# ---------- basics ----------
die() { echo "$(msg err): $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

log_rotate_if_needed() {
  [[ -f "$LOG_FILE" ]] || return 0
  local sz
  sz="$(wc -c <"$LOG_FILE" 2>/dev/null || echo 0)"
  if [[ "$sz" -gt "$LOG_MAX_BYTES" ]]; then
    mv -f "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null || true
  fi
}

log() {
  {
    log_rotate_if_needed
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "$*"
  } >>"$LOG_FILE" 2>/dev/null || true
}

log_file() {
  local title="$1" path="$2"
  {
    log_rotate_if_needed
    printf '%s [%s] ----- %s -----\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "$title"
    if [[ -f "$path" ]]; then cat "$path" 2>/dev/null || true; fi
    printf '%s [%s] ----- end -----\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$"
  } >>"$LOG_FILE" 2>/dev/null || true
}

# ---------- loading ... animation ----------
spin_start() {
  local msg="$1"
  spin_stop
  (
    local n=0
    # disable job-control noise
    set +m
    while true; do
      case $((n % 3)) in
        0) printf '\r%s.  ' "$msg" ;;
        1) printf '\r%s.. ' "$msg" ;;
        2) printf '\r%s...' "$msg" ;;
      esac
      n=$((n + 1))
      sleep 0.35
    done
  ) &
  SPIN_PID=$!
  disown "$SPIN_PID" 2>/dev/null || true
}

spin_stop() {
  if [[ -n "${SPIN_PID:-}" ]]; then
    kill "$SPIN_PID" 2>/dev/null || true
    wait "$SPIN_PID" 2>/dev/null || true
    SPIN_PID=""
  fi
  # clear spinner line
  printf '\r\033[K' 2>/dev/null || printf '\r                              \r'
}

# Run command with spinner; capture stdout to file if given as last args carefully
with_spin() {
  local msg="$1"
  shift
  spin_start "$msg"
  set +e
  "$@"
  local rc=$?
  set -e
  spin_stop
  return "$rc"
}

# ---------- i18n ----------
load_lang() {
  # Session only — never read/write language files on disk.
  if [[ -n "${QUICK_AT_LANG:-}" ]]; then
    UI_LANG="${QUICK_AT_LANG}"
  else
    UI_LANG="$(jq -r '.ui.default_lang // "zh"' "$CATALOG_JSON" 2>/dev/null || echo zh)"
  fi
  case "$UI_LANG" in en|EN) UI_LANG=en ;; *) UI_LANG=zh ;; esac
}
save_lang() {
  # Intentionally no-op: do not persist language (or any user data) locally.
  :
}

msg() {
  local k="$1"
  case "$UI_LANG:$k" in
    zh:err) echo "错误" ;;
    en:err) echo "Error" ;;
    zh:hint_nav) echo "↑↓ 移动 | Enter 确认 | 数字直选 | b 返回 | q 退出" ;;
    en:hint_nav) echo "↑↓ move | Enter select | number | b back | q quit" ;;
    zh:hint_main) echo "↑↓ 移动 | Enter 确认 | 数字直选 | b 模块选择 | q 退出" ;;
    en:hint_main) echo "↑↓ move | Enter select | number | b modem select | q quit" ;;
    zh:hint_modem) echo "↑↓ 移动 | Enter 确认 | 数字直选 | b 返回 | q 退出" ;;
    en:hint_modem) echo "↑↓ move | Enter select | number | b back | q quit" ;;
    zh:prompt) echo "> " ;;
    en:prompt) echo "> " ;;
    zh:invalid) echo "无效选择" ;;
    en:invalid) echo "Invalid choice" ;;
    zh:bye) echo "已退出" ;;
    en:bye) echo "Bye" ;;

    zh:deps) echo "缺少依赖" ;;
    en:deps) echo "Missing deps" ;;
    zh:no_catalog) echo "缺少 at_catalog.json" ;;
    en:no_catalog) echo "Missing at_catalog.json" ;;
    zh:scanning) echo "扫描 Modem" ;;
    en:scanning) echo "Scanning modems" ;;
    zh:no_modem) echo "未发现 Modem" ;;
    en:no_modem) echo "No modem found" ;;
    zh:app_title) echo "移远模块管理脚本" ;;
    en:app_title) echo "Quectel Module Manager" ;;
    zh:pick_modem) echo "选择 Modem" ;;
    en:pick_modem) echo "Select modem" ;;
    zh:refresh) echo "刷新" ;;
    en:refresh) echo "Refresh" ;;
    zh:lang_toggle) echo "切换语言" ;;
    en:lang_toggle) echo "Switch language" ;;
    zh:lang_now) echo "当前" ;;
    en:lang_now) echo "now" ;;
    zh:no_at) echo "该 Modem 无 AT 口" ;;
    en:no_at) echo "No AT port on this modem" ;;
    zh:selected) echo "已选择" ;;
    en:selected) echo "Selected" ;;

    zh:main) echo "主菜单" ;;
    en:main) echo "Main menu" ;;
    zh:port) echo "端口" ;;
    en:port) echo "Port" ;;
    zh:lang) echo "语言" ;;
    en:lang) echo "Language" ;;
    zh:m1) echo "刷新/切换 Modem" ;;
    en:m1) echo "Refresh / switch modem" ;;
    zh:m_at) echo "AT 命令" ;;
    en:m_at) echo "AT commands" ;;
    zh:m_mmcli) echo "mmcli" ;;
    en:m_mmcli) echo "mmcli" ;;
    zh:m_lang) echo "切换语言" ;;
    en:m_lang) echo "Switch language" ;;
    zh:m_log) echo "查看日志" ;;
    en:m_log) echo "View log" ;;
    zh:m_log_clear) echo "清空日志" ;;
    en:m_log_clear) echo "Clear log" ;;

    zh:at_menu) echo "AT 命令" ;;
    en:at_menu) echo "AT commands" ;;
    zh:at1) echo "常用快捷 AT" ;;
    en:at1) echo "Quick AT" ;;
    zh:at2) echo "浏览 AT 目录" ;;
    en:at2) echo "Browse AT catalog" ;;
    zh:at3) echo "搜索手册" ;;
    en:at3) echo "Search catalog" ;;
    zh:at4) echo "自定义 AT" ;;
    en:at4) echo "Custom AT" ;;

    zh:mm_menu) echo "mmcli" ;;
    en:mm_menu) echo "mmcli" ;;
    zh:mm_q) echo "查询" ;;
    en:mm_q) echo "Query" ;;
    zh:mm_op) echo "操作" ;;
    en:mm_op) echo "Actions" ;;
    zh:mm_q_menu) echo "mmcli · 查询" ;;
    en:mm_q_menu) echo "mmcli · Query" ;;
    zh:mm_op_menu) echo "mmcli · 操作" ;;
    en:mm_op_menu) echo "mmcli · Actions" ;;

    zh:mm1) echo "模块详细信息" ;;
    en:mm1) echo "Modem details" ;;
    zh:mm2) echo "SIM 卡信息" ;;
    en:mm2) echo "SIM info" ;;
    zh:mm3) echo "信号质量" ;;
    en:mm3) echo "Signal quality" ;;
    zh:mm4) echo "Messaging 状态" ;;
    en:mm4) echo "Messaging status" ;;
    zh:mm5) echo "读取已存短信" ;;
    en:mm5) echo "Read stored SMS" ;;
    zh:mm6) echo "实时监听短信" ;;
    en:mm6) echo "Live SMS listen" ;;
    zh:mm7) echo "列出全部 Modem" ;;
    en:mm7) echo "List all modems" ;;
    zh:mm8) echo "ModemManager 版本" ;;
    en:mm8) echo "ModemManager version" ;;
    zh:mm9) echo "网络时间" ;;
    en:mm9) echo "Network time" ;;
    zh:mm10) echo "位置信息" ;;
    en:mm10) echo "Location info" ;;
    zh:mm11) echo "位置状态" ;;
    en:mm11) echo "Location status" ;;
    zh:mm12) echo "USSD 状态" ;;
    en:mm12) echo "USSD status" ;;

    zh:mop1) echo "启用 Modem" ;;
    en:mop1) echo "Enable modem" ;;
    zh:mop2) echo "禁用 Modem" ;;
    en:mop2) echo "Disable modem" ;;
    zh:mop3) echo "复位 Modem" ;;
    en:mop3) echo "Reset modem" ;;
    zh:mop4) echo "恢复出厂设置" ;;
    en:mop4) echo "Factory reset" ;;
    zh:mop5) echo "简单连接 (APN)" ;;
    en:mop5) echo "Simple connect (APN)" ;;
    zh:mop6) echo "断开全部连接" ;;
    en:mop6) echo "Disconnect all" ;;
    zh:mop7) echo "注册归属网络" ;;
    en:mop7) echo "Register home network" ;;
    zh:mop8) echo "3GPP 网络扫描" ;;
    en:mop8) echo "3GPP network scan" ;;
    zh:mop9) echo "发送短信" ;;
    en:mop9) echo "Send SMS" ;;
    zh:mop10) echo "删除短信" ;;
    en:mop10) echo "Delete SMS" ;;
    zh:mop11) echo "输入 SIM PIN" ;;
    en:mop11) echo "Enter SIM PIN" ;;
    zh:mop12) echo "输入 SIM PUK" ;;
    en:mop12) echo "Enter SIM PUK" ;;
    zh:mop13) echo "开启 GPS (raw)" ;;
    en:mop13) echo "Enable GPS (raw)" ;;
    zh:mop14) echo "关闭 GPS (raw)" ;;
    en:mop14) echo "Disable GPS (raw)" ;;
    zh:mop15) echo "扫描新 Modem" ;;
    en:mop15) echo "Scan for modems" ;;
    zh:mop16) echo "发起 USSD" ;;
    en:mop16) echo "Initiate USSD" ;;
    zh:mop17) echo "取消 USSD" ;;
    en:mop17) echo "Cancel USSD" ;;

    zh:mm_running) echo "执行中" ;;
    en:mm_running) echo "Running" ;;
    zh:mm_no_sim) echo "未找到 SIM 路径" ;;
    en:mm_no_sim) echo "No SIM path found" ;;
    zh:mm_apn_ask) echo "APN" ;;
    en:mm_apn_ask) echo "APN" ;;
    zh:mm_sms_to) echo "收件号码" ;;
    en:mm_sms_to) echo "Recipient number" ;;
    zh:mm_sms_text) echo "短信内容" ;;
    en:mm_sms_text) echo "SMS text" ;;
    zh:mm_sms_id) echo "短信 Id（mmcli -s 的编号）" ;;
    en:mm_sms_id) echo "SMS id (mmcli -s index)" ;;
    zh:mm_pin_ask) echo "SIM PIN" ;;
    en:mm_pin_ask) echo "SIM PIN" ;;
    zh:mm_puk_ask) echo "SIM PUK" ;;
    en:mm_puk_ask) echo "SIM PUK" ;;
    zh:mm_factory_code) echo "出厂复位码" ;;
    en:mm_factory_code) echo "Factory reset code" ;;
    zh:mm_confirm_op) echo "确认执行此操作？[y/N]" ;;
    en:mm_confirm_op) echo "Confirm this action? [y/N]" ;;
    zh:mm_confirm_dang) echo "危险操作，确认执行？[y/N]" ;;
    en:mm_confirm_dang) echo "Dangerous action. Confirm? [y/N]" ;;
    zh:mm_ussd_ask) echo "USSD 命令（如 *100#）" ;;
    en:mm_ussd_ask) echo "USSD command (e.g. *100#)" ;;

    zh:quick) echo "常用快捷" ;;
    en:quick) echo "Quick presets" ;;
    zh:pick_cmd) echo "选择命令" ;;
    en:pick_cmd) echo "Select command" ;;
    zh:manual) echo "浏览 AT 目录" ;;
    en:manual) echo "Browse AT catalog" ;;
    zh:chapter) echo "选择章节（AT / QCFG / QSIMCFG）" ;;
    en:chapter) echo "Select chapter (AT / QCFG / QSIMCFG)" ;;
    zh:empty) echo "(空)" ;;
    en:empty) echo "(empty)" ;;
    zh:danger) echo "[危险]" ;;
    en:danger) echo "[DANGER]" ;;

    zh:imei_ask) echo "输入 15 位 IMEI（将发送 AT+EGMR=1,7,\"<IMEI>\"）" ;;
    en:imei_ask) echo "Enter 15-digit IMEI (sends AT+EGMR=1,7,\"<IMEI>\")" ;;
    zh:imei_bad) echo "IMEI 无效：需要 14–16 位数字" ;;
    en:imei_bad) echo "Invalid IMEI: need 14–16 digits" ;;

    zh:search_ask) echo "关键字" ;;
    en:search_ask) echo "Keyword" ;;
    zh:search_none) echo "无匹配" ;;
    en:search_none) echo "No match" ;;
    zh:searching) echo "搜索中" ;;
    en:searching) echo "Searching" ;;
    zh:custom_ask) echo "AT 命令" ;;
    en:custom_ask) echo "AT command" ;;

    zh:sending) echo "发送 AT" ;;
    en:sending) echo "Sending AT" ;;
    zh:resp) echo "响应" ;;
    en:resp) echo "Response" ;;
    zh:timeout) echo "(超时无响应)" ;;
    en:timeout) echo "(timeout, no response)" ;;
    zh:confirm_dang) echo "危险命令，确认执行？[y/N]" ;;
    en:confirm_dang) echo "Dangerous command. Confirm? [y/N]" ;;
    zh:cancelled) echo "已取消" ;;
    en:cancelled) echo "Cancelled" ;;
    zh:reboot_ask) echo "需重启生效，发送 AT+CFUN=1,1？[y/N]" ;;
    en:reboot_ask) echo "Reboot needed. Send AT+CFUN=1,1? [y/N]" ;;
    zh:rebooting) echo "重启中" ;;
    en:rebooting) echo "Rebooting" ;;

    zh:reading_sms) echo "读取短信" ;;
    en:reading_sms) echo "Reading SMS" ;;
    zh:listen) echo "监听中（Ctrl+C 返回）" ;;
    en:listen) echo "Listening (Ctrl+C to return)" ;;
    zh:need_modem) echo "请先选择 Modem" ;;
    en:need_modem) echo "Select a modem first" ;;
    zh:no_sms) echo "没有短信" ;;
    en:no_sms) echo "No SMS" ;;
    zh:log_cleared) echo "日志已清空" ;;
    en:log_cleared) echo "Log cleared" ;;
    zh:clear_ask) echo "确认清空日志？[y/N]" ;;
    en:clear_ask) echo "Clear log? [y/N]" ;;
    zh:lang_ok) echo "语言已切换" ;;
    en:lang_ok) echo "Language switched" ;;
    zh:press_enter) echo "回车继续 | b=返回 | q=退出 > " ;;
    en:press_enter) echo "Enter=continue | b=back | q=quit > " ;;
    zh:int_hint) echo "已取消（再按一次 Ctrl+C 退出）" ;;
    en:int_hint) echo "Cancelled (Ctrl+C again to quit)" ;;
    zh:int_back) echo "已中断，返回菜单" ;;
    en:int_back) echo "Interrupted — back to menu" ;;

    *) echo "[$k]" ;;
  esac
}

label_field() { [[ "$UI_LANG" == en ]] && echo label_en || echo label_zh; }

# ---------- immersive CLI frame ----------
ui_clear() {
  spin_stop
  if [[ -t 1 ]]; then
    clear 2>/dev/null || printf '\033[H\033[2J'
  else
    printf '\n'
  fi
}

ui_header() {
  local lang_disp="中文"
  [[ "$UI_LANG" == en ]] && lang_disp="English"
  printf '%s\n' "════════════════════════════════════════"
  printf '  %s\n' "$(msg app_title)"
  if [[ -n "${SELECTED_PORT:-}" ]]; then
    printf '  %s\n' "$SELECTED_LABEL"
    printf '  %s: %s  |  %s: %s\n' "$(msg port)" "$SELECTED_PORT" "$(msg lang)" "$lang_disp"
  elif [[ -n "${SELECTED_MODEM_ID:-}" ]]; then
    printf '  %s\n' "$SELECTED_LABEL"
  fi
  if [[ "$PERSIST_LOG" -eq 1 ]]; then
    printf '  log: %s\n' "$LOG_FILE"
  fi
  printf '%s\n' "════════════════════════════════════════"
}

hr() { printf '%s\n' "────────────────────────────────────────"; }

# After AT/result screens. returns: 0=continue, 1=back, 2=quit, 3=interrupted
pause_nav() {
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    return 3
  fi
  echo
  printf '%s' "$(msg press_enter)"
  local ans="" read_rc=0
  INTERRUPTED=0
  # `|| read_rc=$?` keeps this errexit-safe WITHOUT toggling set -e.
  read -r ans || read_rc=$?
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    return 3
  fi
  # EOF / closed stdin → back (never quit the whole app)
  if [[ $read_rc -ne 0 ]]; then
    return 1
  fi
  ans="${ans//$'\r'/}"
  ans="$(printf '%s' "$ans" | tr -d '[:space:]')"
  case "$ans" in
    q|Q|quit|exit) return 2 ;;
    b|B|back) return 1 ;;
    *) return 0 ;;
  esac
}

# Simple pause (SMS/log). Any key / Enter continues; never quits.
pause() {
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    return 0
  fi
  echo
  printf '%s' "$(msg press_enter)"
  INTERRUPTED=0
  read -r _ || true
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
  fi
  return 0
}

# empty_mode: back | refresh
# returns: 0=ok, 1=back, 2=quit, 3=interrupted (redraw)
read_choice() {
  local empty_mode="${1:-back}"
  INTERRUPTED=0
  printf '%s' "$(msg prompt)"
  local read_rc=0
  # `|| read_rc=$?` keeps this errexit-safe WITHOUT toggling set -e,
  # so a non-zero return (b/q/EOF) can never leak errexit and kill the app.
  read -r CHOICE || read_rc=$?
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    CHOICE=""
    return 3
  fi
  # EOF → back one level (do NOT quit; avoids socat/tty glitches killing the app)
  if [[ $read_rc -ne 0 ]]; then
    CHOICE=""
    return 1
  fi
  # Strip CR (Windows) and whitespace
  CHOICE="${CHOICE//$'\r'/}"
  CHOICE="$(printf '%s' "$CHOICE" | tr -d '[:space:]')"
  if [[ -z "$CHOICE" ]]; then
    case "$empty_mode" in
      refresh)
        CHOICE=1
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  fi
  case "$CHOICE" in
    q|Q|quit|exit) return 2 ;;
    b|B|back) return 1 ;;
    *) return 0 ;;
  esac
}

# Run a submenu. Sets CALL_MENU_RC to submenu status (0=back/ok, 2=quit).
# `|| CALL_MENU_RC=$?` is errexit-exempt, so a submenu that returns non-zero
# (or leaks set -e internally) can never abort the whole script here.
call_menu() {
  CALL_MENU_RC=0
  "$@" || CALL_MENU_RC=$?
  return 0
}

confirm_yn() {
  printf '%s ' "$1"
  local a
  INTERRUPTED=0
  read -r a || true
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    return 1
  fi
  case "${a:-n}" in y|Y|yes|YES|是) return 0 ;; *) return 1 ;; esac
}

ask_line() {
  printf '%s: ' "$1"
  INTERRUPTED=0
  read -r ASK_VAL || true
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    ASK_VAL=""
    return 1
  fi
  ASK_VAL="${ASK_VAL:-}"
  return 0
}

# Clear screen, sticky header, then menu. Keeps UI pinned at top (immersive).
print_menu() {
  local title="$1"
  local hint="$2"
  shift 2
  ui_clear
  ui_header
  echo
  echo "  $title"
  hr
  local i=1
  local item
  for item in "$@"; do
    printf '  %2d) %s\n' "$i" "$item"
    i=$((i + 1))
  done
  echo
  echo "  ${hint}"
  hr
}

# Optional one-line note shown under the item list (e.g. "no modem").
MENU_NOTE=""
# Remembered highlight position (1-based) for the arrow-key selector.
MENU_SEL_IDX=1

# Render the menu with a '>' marker on the current row.
# Flicker-free: home the cursor and overwrite each line (\033[K) instead of
# clearing the whole screen. The caller clears the screen ONCE beforehand.
render_menu_highlight() {
  local title="$1" hint="$2" sel="$3"; shift 3
  local -a lines=()
  local hdr l
  hdr="$(ui_header)"
  while IFS= read -r l; do lines+=("$l"); done <<< "$hdr"
  lines+=("")
  lines+=("  $title")
  lines+=("────────────────────────────────────────")
  local i=1 item
  for item in "$@"; do
    if [[ $i -eq $sel ]]; then
      lines+=("$(printf '  > %2d) %s' "$i" "$item")")
    else
      lines+=("$(printf '    %2d) %s' "$i" "$item")")
    fi
    i=$((i + 1))
  done
  [[ -n "$MENU_NOTE" ]] && { lines+=(""); lines+=("  $MENU_NOTE"); }
  lines+=("")
  lines+=("  ${hint}")
  lines+=("────────────────────────────────────────")
  if [[ -t 1 ]]; then
    # Home, then overwrite each line clearing to EOL; clear the rest below.
    printf '\033[H'
    for l in "${lines[@]}"; do
      printf '%s\033[K\n' "$l"
    done
    printf '\033[J'
  else
    printf '%s\n' "${lines[@]}"
  fi
}

# Interactive selector with arrow keys (↑↓ / j k), number entry, b/ESC=back, q=quit.
# Usage: menu_select MODE TITLE HINT ITEM...
#   MODE: back | refresh (only affects the non-tty fallback via read_choice)
# Sets CHOICE to the selected 1-based index.
# Returns: 0=selected, 1=back, 2=quit, 3=interrupted (redraw). Never leaks set -e.
menu_select() {
  local mode="$1" title="$2" hint="$3"; shift 3
  local items=("$@")
  local n=${#items[@]}

  # Non-interactive (piped/redirected stdin) → classic numbered prompt.
  if [[ ! -t 0 ]]; then
    print_menu "$title" "$hint" "${items[@]}"
    [[ -n "$MENU_NOTE" ]] && echo "  $MENU_NOTE"
    local rc=0
    read_choice "$mode" || rc=$?
    return $rc
  fi

  # Clear the screen ONCE; the render then repaints in place (no flicker).
  ui_clear

  if (( n == 0 )); then
    render_menu_highlight "$title" "$hint" 0 "${items[@]}"
    CHOICE=""
    return 1
  fi

  local sel=${MENU_SEL_IDX:-1}
  (( sel < 1 )) && sel=1
  (( sel > n )) && sel=n
  local numbuf=""

  INTERRUPTED=0
  while true; do
    render_menu_highlight "$title" "$hint" "$sel" "${items[@]}"
    local key="" rc=0
    IFS= read -rsn1 key || rc=$?
    if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then INTERRUPTED=0; CHOICE=""; return 3; fi
    if [[ $rc -ne 0 ]]; then CHOICE=""; return 1; fi   # EOF → back
    case "$key" in
      $'\x1b')  # ESC: bare = back, or start of an arrow sequence
        local seq=""
        read -rsn2 -t 0.1 seq 2>/dev/null || true
        case "$seq" in
          '[A'|'OA') numbuf=""; (( sel > 1 )) && sel=$((sel - 1)) || sel=$n ;;  # up (wrap)
          '[B'|'OB') numbuf=""; (( sel < n )) && sel=$((sel + 1)) || sel=1 ;;   # down (wrap)
          '[C'|'OC'|'[D'|'OD') ;;                                               # left/right ignore
          '') CHOICE=""; return 1 ;;                                            # bare ESC → back
          *) ;;
        esac
        ;;
      ''|$'\n'|$'\r')  # Enter → select highlighted row
        CHOICE="$sel"; MENU_SEL_IDX=$sel; return 0
        ;;
      [0-9])
        numbuf="${numbuf}${key}"
        if [[ "$numbuf" =~ ^0*([1-9][0-9]*)$ ]]; then
          local cand=$((10#$numbuf))
          if (( cand >= 1 && cand <= n )); then
            sel=$cand
          else
            numbuf="$key"
            (( 10#$numbuf >= 1 && 10#$numbuf <= n )) && sel=$((10#$numbuf))
          fi
        fi
        ;;
      k|K) numbuf=""; (( sel > 1 )) && sel=$((sel - 1)) || sel=$n ;;  # vim up
      j|J) numbuf=""; (( sel < n )) && sel=$((sel + 1)) || sel=1 ;;   # vim down
      b|B) CHOICE=""; return 1 ;;
      q|Q) CHOICE=""; return 2 ;;
      *) ;;
    esac
  done
}

# ---------- deps ----------
check_deps() {
  local missing=() c
  for c in mmcli socat jq timeout awk sed; do
    have_cmd "$c" || missing+=("$c")
  done
  if ((${#missing[@]})); then
    die "$(msg deps): ${missing[*]}"
  fi
}

check_sms_deps() {
  have_cmd mmcli || { echo "$(msg deps): mmcli"; return 1; }
  [[ -n "${SELECTED_MODEM_ID:-}" ]] || { echo "$(msg need_modem)"; return 1; }
  return 0
}

# List SMS indices on selected modem (mmcli --messaging-list-sms).
# Prints one index per line (numeric).
mmcli_sms_indices() {
  local mid="${1:-$SELECTED_MODEM_ID}" line
  timeout --foreground 8s mmcli -m "$mid" --messaging-list-sms 2>>"$LOG_FILE" |
    awk '
      match($0, /\/SMS\/[0-9]+/) {
        s = substr($0, RSTART, RLENGTH)
        sub(/.*\//, "", s)
        print s
      }
    '
}

# Show one SMS: number / text / timestamp / state / storage.
mmcli_sms_show() {
  local sid="$1" raw number text state ts storage
  raw="$(timeout --foreground 5s mmcli -s "$sid" 2>>"$LOG_FILE")" || return 1
  number="$(printf '%s\n' "$raw" | sed -n "s/.*number:[[:space:]]*'\\?\\([^']*\\)'\\?.*/\\1/ip" | head -n1)"
  text="$(printf '%s\n' "$raw" | sed -n "s/.*[[:space:]]text:[[:space:]]*'\\?\\([^']*\\)'\\?.*/\\1/ip" | head -n1)"
  state="$(printf '%s\n' "$raw" | sed -n "s/.*state:[[:space:]]*'\\?\\([^']*\\)'\\?.*/\\1/ip" | head -n1)"
  ts="$(printf '%s\n' "$raw" | sed -n "s/.*timestamp:[[:space:]]*'\\?\\([^']*\\)'\\?.*/\\1/ip" | head -n1)"
  storage="$(printf '%s\n' "$raw" | sed -n "s/.*storage:[[:space:]]*'\\?\\([^']*\\)'\\?.*/\\1/ip" | head -n1)"
  # Trim leftover quotes/spaces
  number="$(printf '%s' "$number" | sed "s/^['\\\"[:space:]]*//;s/['\\\"[:space:]]*$//")"
  text="$(printf '%s' "$text" | sed "s/^['\\\"[:space:]]*//;s/['\\\"[:space:]]*$//")"
  state="$(printf '%s' "$state" | sed "s/^['\\\"[:space:]]*//;s/['\\\"[:space:]]*$//")"
  ts="$(printf '%s' "$ts" | sed "s/^['\\\"[:space:]]*//;s/['\\\"[:space:]]*$//")"
  storage="$(printf '%s' "$storage" | sed "s/^['\\\"[:space:]]*//;s/['\\\"[:space:]]*$//")"
  echo "------------------------------------------------------------"
  echo "From: ${number:-?}"
  echo "Time: ${ts:-?}"
  echo "State: ${state:-?}  Storage: ${storage:-?}  Id: $sid"
  echo "Text: ${text:-}"
}

mmcli_sms_dump_all() {
  local mid="${1:-$SELECTED_MODEM_ID}" ids id count=0
  mapfile -t ids < <(mmcli_sms_indices "$mid")
  if ((${#ids[@]} == 0)); then
    echo "$(msg no_sms)"
    return 0
  fi
  for id in "${ids[@]}"; do
    [[ -n "$id" ]] || continue
    mmcli_sms_show "$id" || echo "(failed to read SMS $id)"
    count=$((count + 1))
  done
  echo "------------------------------------------------------------"
  echo "Total: $count"
}

# ---------- AT / notes (jq) ----------
append_pdf_notes() {
  local cmd="$1"
  local notes
  set +e
  notes="$(jq -r --arg cmd "$cmd" --arg lang "$UI_LANG" '
    def norm: ascii_upcase | gsub("[[:space:]]"; "");
    def cmd_match($inp; $stem):
      ($stem | length) as $n
      | ($n > 0) and (
          ($inp == $stem)
          or (
            ($inp | startswith($stem))
            and (
              (($inp | length) == $n)
              or (($inp[$n:$n+1]) as $c
                  | $c == "=" or $c == "?" or $c == "," or $c == "\"")
            )
          )
        );

    ($cmd | norm) as $inp
    | . as $root
    | (
        [ ($root.response_docs // {}) | to_entries[]
          | (.key | norm) as $stem
          | select(cmd_match($inp; $stem))
          | {key: .key, len: ($stem | length), doc: .value}
        ]
        | sort_by(-.len)
        | .[0]
      ) as $hit
    | (
        [ ($root.commands // [])[]
          | ((.cmd // "") | norm) as $stem
          | select(cmd_match($inp; $stem))
          | {len: ($stem | length), c: .}
        ]
        | sort_by(-.len)
        | .[0]
      ) as $chit
    | (
        [
          (($root.quick_presets // [])[] | (.actions // [.])[]),
          (($root.category_presets // [])[] | (.actions // [.])[])
        ]
        | map(select(((.cmd // "") | norm) == $inp))
        | .[0] // null
      ) as $preset
    | (
        if $preset == null then ""
        elif $lang == "en" then ($preset.notes_en // $preset.notes // "")
        else ($preset.notes_zh // $preset.notes // "")
        end
      ) as $pnote

    | if $hit != null then
        (if $lang == "en" then
          "",
          "===== Manual notes (PDF) =====",
          ("Reference: " + ($hit.doc.ref // "")),
          ("Response format: " + ($hit.doc.response_en // "")),
          "Parameters:"
        else
          "",
          "===== 手册注释 (PDF) =====",
          ("出处: " + ($hit.doc.ref // "")),
          ("返回格式: " + ($hit.doc.response_zh // "")),
          "参数说明:"
        end),
        (
          (if $lang == "en" then ($hit.doc.params_en // [])
           else ($hit.doc.params_zh // []) end)[]
          | "  - \(.)"
        )
      elif $chit != null then
        (
          (($root.sources // {})[$chit.c.source // ""] // {}) as $src
          | ($src.label // $chit.c.source // "") as $slabel
          | (if ($chit.c.section // "") != "" then ($slabel + " §" + ($chit.c.section | tostring))
             else $slabel end) as $ref
          | if $lang == "en" then
              "",
              "===== Manual notes (PDF) =====",
              "(No detailed parameter notes; title/section from manual TOC)",
              ("Command: " + ($chit.c.title // $chit.c.title_en // "")),
              ("Reference: " + $ref)
            else
              "",
              "===== 手册注释 (PDF) =====",
              "(目录中无详细参数注释；以下为手册标题/章节)",
              ("命令用途: " + ($chit.c.title_zh // $chit.c.title // "")),
              ("出处: " + $ref)
            end
        )
      else empty
      end
    ,
    (if ($pnote | length) > 0 then
      "",
      (if $lang == "en" then ("Preset note: " + $pnote) else ("快捷说明: " + $pnote) end)
     else empty end)
  ' "$CATALOG_JSON" 2>>"$LOG_FILE")"
  set -e
  if [[ -n "${notes}" ]]; then
    printf '%s\n' "$notes" >>"$RESP_FILE"
  fi
}

send_at() {
  local port="$1" cmd="$2" timeout_sec="${3:-5}"
  local upper
  upper="$(printf '%s' "$cmd" | tr '[:lower:]' '[:upper:]' | tr -d ' ')"
  # Quectel AT Manual: CMGL max response time 300ms; allow PDU transfer headroom.
  [[ "$upper" == AT+CMGL* || "$upper" == AT+CMGR* ]] && timeout_sec=10

  log "AT>>> port=$port timeout=${timeout_sec}s cmd=$cmd"
  local err_file="${WORKDIR}/socat.err" rc
  : >"$RESP_FILE"
  : >"$err_file"

  ui_clear
  ui_header
  echo
  echo "  >>> $cmd"
  echo
  spin_start "$(msg sending)"
  set +e
  printf '%s\n' "$cmd" |
    timeout --foreground "${timeout_sec}s" socat - "${port},crnl" \
      >"$RESP_FILE" 2>"$err_file"
  rc=${PIPESTATUS[1]}
  set -e
  spin_stop

  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    echo "$(msg int_back)" >"$RESP_FILE"
    log "AT interrupted"
    return 130
  fi

  log "AT<<< socat rc=$rc bytes=$(wc -c <"$RESP_FILE")"
  [[ -s "$err_file" ]] && log_file "socat stderr" "$err_file"
  if [[ ! -s "$RESP_FILE" ]]; then
    if [[ "$rc" -eq 124 ]]; then
      echo "$(msg timeout)" >"$RESP_FILE"
    elif [[ -s "$err_file" ]]; then
      cp "$err_file" "$RESP_FILE"
    else
      echo "(socat rc=$rc)" >"$RESP_FILE"
    fi
  fi
  append_pdf_notes "$cmd"
  log_file "AT response" "$RESP_FILE"
}

show_response() {
  local title="${1:-$(msg resp)}"
  ui_clear
  ui_header
  echo
  echo "  $title"
  hr
  cat "$RESP_FILE"
  echo
  hr
}

cmd_is_dangerous() {
  local cmd="$1" note
  note="$(jq -r --arg cmd "$cmd" --arg lang "$UI_LANG" '
    ($cmd | ascii_upcase | gsub("[[:space:]]"; "")) as $input
    | first(
        .dangerous[]
        | (.cmd | ascii_upcase | gsub("[[:space:]]"; "")) as $base
        | select($input | startswith($base))
        | (if $lang=="en" then (.notes_en // .notes // .label_en // .label_zh)
           else (.notes_zh // .notes // .label_zh) end)
      ) // empty
  ' "$CATALOG_JSON")"
  [[ -n "$note" ]] || return 1
  printf '%s\n' "$note"
}

confirm_dangerous() {
  local cmd="$1" note
  if ! note="$(cmd_is_dangerous "$cmd")"; then
    return 0
  fi
  echo
  echo "$(msg danger) $cmd"
  echo "  $note"
  confirm_yn "$(msg confirm_dang)"
}

cmd_needs_reboot() {
  local cmd="$1"
  case "$cmd" in
    AT+EGMR=1,7,*|at+egmr=1,7,*) return 0 ;;
  esac
  jq -e --arg cmd "$cmd" '
    [
      (.quick_presets // [])[] | (.actions // [])[],
      (.category_presets // [])[] | (.actions // [])[]
    ]
    | map(select(.needs_reboot == true) | .cmd)
    | any(. == $cmd)
  ' "$CATALOG_JSON" >/dev/null 2>&1
}

offer_reboot() {
  local cmd="$1"
  cmd_needs_reboot "$cmd" || return 0
  if confirm_yn "$(msg reboot_ask)"; then
    send_at "$SELECTED_PORT" "AT+CFUN=1,1" 5
    show_response "AT+CFUN=1,1"
  fi
}

run_at_and_followup() {
  # Always returns 0 (set -e safe). Sets NAV_AFTER_AT: 0=continue 1=back 2=quit
  local cmd="$1" prc=0
  NAV_AFTER_AT=0
  log "run_at: $cmd"
  INTERRUPTED=0
  if ! confirm_dangerous "$cmd"; then
    echo "$(msg cancelled)"
    NAV_AFTER_AT=0
    return 0
  fi
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    NAV_AFTER_AT=0
    return 0
  fi
  set +e
  send_at "$SELECTED_PORT" "$cmd" 5
  local send_rc=$?
  set -e
  if [[ $send_rc -eq 130 ]]; then
    set +e
    pause_nav
    prc=$?
    set -e
    if [[ $prc -eq 3 ]]; then prc=0; fi
    NAV_AFTER_AT=$prc
    return 0
  fi
  show_response "$(msg resp): $cmd"
  set +e
  offer_reboot "$cmd"
  set -e
  set +e
  pause_nav
  prc=$?
  set -e
  if [[ $prc -eq 3 ]]; then prc=0; fi
  NAV_AFTER_AT=$prc
  return 0
}

# ---------- modem ----------
mmcli_field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    index(tolower($0), tolower(key) ":") {
      line=$0
      sub(/^.*:[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$file"
}

mmcli_at_ports() {
  awk '
    {
      line=$0
      while (match(line, /(ttyUSB|ttyACM)[0-9]+[[:space:]]+\(at\)/)) {
        item=substr(line, RSTART, RLENGTH)
        sub(/[[:space:]]+\(at\)$/, "", item)
        print "/dev/" item
        line=substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

mmcli_ids() {
  timeout --foreground 5s mmcli -L 2>>"$LOG_FILE" |
    awk 'match($0, /Modem\/[0-9]+/) { print substr($0, RSTART + 6, RLENGTH - 6) }' |
    sort -n
}

smallest_at_port() {
  local ports=("$@") best="" best_num=999999 p base num
  for p in "${ports[@]}"; do
    base="${p##*/}"
    num="$(echo "$base" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)$/\1/p')"
    [[ -n "$num" ]] || num=999998
    if [[ -z "$best" ]] || ((10#$num < best_num)); then
      best="$p"
      best_num=$((10#$num))
    fi
  done
  printf '%s\n' "$best"
}

pick_port() {
  if ((${#MODEM_PORTS[@]} == 0)); then
    echo "$(msg no_at)"
    return 1
  fi
  SELECTED_PORT="$(smallest_at_port "${MODEM_PORTS[@]}")"
  [[ -n "$SELECTED_PORT" ]] || SELECTED_PORT="${MODEM_PORTS[0]}"
  log "port=$SELECTED_PORT"
  return 0
}

pick_modem() {
  local skip_scan=0
  local ids=()
  while true; do
    local labels=() menu_labels=() mid operator_name operator_id imei ports label

    if [[ "$skip_scan" -eq 0 ]]; then
      ids=()
      ui_clear
      ui_header
      echo
      INTERRUPTED=0
      spin_start "$(msg scanning)"
      set +e
      mapfile -t ids < <(mmcli_ids)
      set -e
      spin_stop
      if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
        INTERRUPTED=0
        skip_scan=1
        continue
      fi
      log "mmcli ids=${ids[*]-}"

      for mid in "${ids[@]}"; do
        local detail="${WORKDIR}/modem_${mid}.txt"
        spin_start "mmcli -m $mid"
        set +e
        timeout --foreground 5s mmcli -m "$mid" >"$detail" 2>>"$LOG_FILE"
        set -e
        spin_stop
        if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
          INTERRUPTED=0
          break
        fi
        log_file "mmcli modem $mid" "$detail"
      done
    fi
    skip_scan=0

    menu_labels+=("$(msg refresh)")
    labels+=("refresh")

    for mid in "${ids[@]}"; do
      local detail="${WORKDIR}/modem_${mid}.txt"
      operator_name="$(mmcli_field "$detail" "operator name")"
      operator_id="$(mmcli_field "$detail" "operator id")"
      imei="$(mmcli_field "$detail" "equipment id")"
      ports="$(mmcli_at_ports "$detail" | awk 'BEGIN{f=1}{if(!f)printf ", ";printf "%s",$0;f=0}END{print""}')"
      label="Modem ${mid}"
      [[ -n "$operator_name" && "$operator_name" != "--" ]] && label+=" | ${operator_name}"
      [[ -n "$operator_id" && "$operator_id" != "--" ]] && label+=" (${operator_id})"
      [[ -n "$imei" ]] && label+=" | IMEI ${imei}"
      [[ -n "$ports" ]] && label+=" | AT: ${ports}"
      menu_labels+=("$label")
      labels+=("$mid")
    done

    local lang_disp="中文"
    [[ "$UI_LANG" == en ]] && lang_disp="English"
    menu_labels+=("$(msg lang_toggle) ($(msg lang_now): ${lang_disp})")
    labels+=("lang")

    MENU_NOTE=""
    ((${#ids[@]} == 0)) && MENU_NOTE="$(msg no_modem)"
    local st=0
    menu_select refresh "$(msg pick_modem)" "$(msg hint_modem)" "${menu_labels[@]}" || st=$?
    MENU_NOTE=""
    case "$st" in
      2) return 2 ;; # quit → caller exits
      1) return 1 ;; # back
      3) skip_scan=1; continue ;;
    esac

    if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#labels[@]})); then
      echo "$(msg invalid)"
      sleep 0.8
      skip_scan=1
      continue
    fi
    local idx=$((CHOICE - 1))
    local key="${labels[$idx]}"
    if [[ "$key" == "refresh" ]]; then
      continue
    fi
    if [[ "$key" == "lang" ]]; then
      if [[ "$UI_LANG" == en ]]; then
        UI_LANG=zh
      else
        UI_LANG=en
      fi
      save_lang
      log "lang toggled -> $UI_LANG"
      skip_scan=1
      continue
    fi

    SELECTED_MODEM_ID="$key"
    local selected_detail="${WORKDIR}/modem_${SELECTED_MODEM_ID}.txt"
    operator_name="$(mmcli_field "$selected_detail" "operator name")"
    operator_id="$(mmcli_field "$selected_detail" "operator id")"
    imei="$(mmcli_field "$selected_detail" "equipment id")"
    SELECTED_LABEL="Modem ${SELECTED_MODEM_ID}"
    [[ -n "$operator_name" && "$operator_name" != "--" ]] && SELECTED_LABEL+=" | ${operator_name}"
    [[ -n "$operator_id" && "$operator_id" != "--" ]] && SELECTED_LABEL+=" (${operator_id})"
    [[ -n "$imei" ]] && SELECTED_LABEL+=" | IMEI ${imei}"
    mapfile -t MODEM_PORTS < <(mmcli_at_ports "$selected_detail")
    return 0
  done
}

# ---------- menus ----------
resolve_quick_cmd() {
  local template="$1"
  RESOLVED_CMD=""
  if [[ "$template" != *"<IMEI>"* ]]; then
    RESOLVED_CMD="$template"
    return 0
  fi
  ask_line "$(msg imei_ask)" || return 1
  local imei
  imei="$(printf '%s' "$ASK_VAL" | tr -d '[:space:]-')"
  if [[ ! "$imei" =~ ^[0-9]{14,16}$ ]]; then
    echo "$(msg imei_bad)"
    return 1
  fi
  RESOLVED_CMD="${template//<IMEI>/$imei}"
  return 0
}

menu_quick() {
  # return 0 = back to main; return 2 = quit
  while true; do
    local lf ids=() labels=() action_counts=() id label cmd nact st
    lf="$(label_field)"
    while IFS=$'\t' read -r id label cmd nact; do
      [[ -n "$id" ]] || continue
      ids+=("$id")
      labels+=("${label}  →  ${cmd}")
      action_counts+=("$nact")
    done < <(jq -r --arg lf "$lf" '
      .quick_presets[]
      | . as $g
      | (($g.actions // []) | length) as $n
      | "\($g.id)\t\($g[$lf] // $g.label_zh // $g.label_en // "")\t\($g.cmd // "")\t\($n)"
    ' "$CATALOG_JSON")

    st=0
    menu_select back "$(msg quick)" "$(msg hint_nav)" "${labels[@]}" || st=$?
    case "$st" in
      2) return 2 ;; # quit
      1) return 0 ;; # back → main
      3) continue ;;
    esac
    if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#ids[@]})); then
      echo "$(msg invalid)"; sleep 0.6; continue
    fi
    local gidx=$((CHOICE - 1))
    local gid="${ids[$gidx]}"
    local n="${action_counts[$gidx]}"

    local template=""
    if [[ "$n" -le 1 ]]; then
      template="$(jq -r --argjson id "$gid" '
        .quick_presets[] | select(.id == $id)
        | (.actions[0].cmd // .cmd // empty)
      ' "$CATALOG_JSON")"
    else
      while true; do
        local alabels=() acmds=() alabel acmd
        while IFS=$'\t' read -r alabel acmd; do
          [[ -n "$acmd" ]] || continue
          alabels+=("${alabel}  →  ${acmd}")
          acmds+=("$acmd")
        done < <(jq -r --argjson id "$gid" --arg lf "$lf" '
          .quick_presets[] | select(.id == $id) | (.actions // [])[]
          | "\(.[$lf] // .label_zh // .label_en // "")\t\(.cmd)"
        ' "$CATALOG_JSON")

        st=0
        menu_select back "$(msg pick_cmd)" "$(msg hint_nav)" "${alabels[@]}" || st=$?
        case "$st" in
          2) return 2 ;;          # quit
          1) continue 2 ;;        # back → group list
          3) continue ;;
        esac
        if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#acmds[@]})); then
          echo "$(msg invalid)"; sleep 0.6; continue
        fi
        template="${acmds[$((CHOICE - 1))]}"
        break
      done
    fi

    [[ -n "$template" ]] || continue
    resolve_quick_cmd "$template" || continue
    run_at_and_followup "$RESOLVED_CMD"
    case "${NAV_AFTER_AT:-0}" in
      2) return 2 ;;
      1) continue ;; # back → group list
    esac
  done
}

menu_category() {
  # Merged AT+QCFG+QSIMCFG catalog. return 0 = back to main; return 2 = quit
  local st
  while true; do
    local cat_ids=() cat_labels=() c name
    while IFS=$'\t' read -r c name; do
      [[ -n "$c" ]] || continue
      cat_ids+=("$c")
      cat_labels+=("$name")
    done < <(jq -r --arg lang "$UI_LANG" '
      def src_rank:
        if . == "at" then 0
        elif . == "qcfg" then 1
        elif . == "qsimcfg" then 2
        else 9 end;
      def src_tag:
        if . == "at" then "AT"
        elif . == "qcfg" then "QCFG"
        elif . == "qsimcfg" then "QSIMCFG"
        else (. | ascii_upcase) end;
      .categories | to_entries
      | sort_by([(.value.source | src_rank), (.value.order // 0)])
      | .[]
      | (.value.source | src_tag) as $tag
      | (.value[$lang] // .value.zh // .value.en // .key) as $title
      | "\(.key)\t\($tag) · \($title)"
    ' "$CATALOG_JSON")

    if ((${#cat_ids[@]} == 0)); then
      echo "$(msg empty)"
      return 0
    fi
    st=0
    menu_select back "$(msg chapter)" "$(msg hint_nav)" "${cat_labels[@]}" || st=$?
    case "$st" in
      2) return 2 ;;
      1) return 0 ;; # back → main
      3) continue ;;
    esac
    if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#cat_ids[@]})); then
      echo "$(msg invalid)"; sleep 0.6; continue
    fi
    local cat="${cat_ids[$((CHOICE - 1))]}"
    local cat_title="${cat_labels[$((CHOICE - 1))]}"

    while true; do
      local gids=() glabels=() gcmds=() gnacts=() id label cmd nact dang
      local lf danger_tag
      lf="$(label_field)"
      danger_tag="$(msg danger)"
      while IFS=$'\t' read -r id label cmd nact dang; do
        [[ -n "$id" ]] || continue
        gids+=("$id")
        gcmds+=("$cmd")
        gnacts+=("$nact")
        if [[ "$dang" == "true" ]]; then
          glabels+=("${danger_tag} ${label}  →  ${cmd}")
        else
          glabels+=("${label}  →  ${cmd}")
        fi
      done < <(jq -r --arg c "$cat" --arg lf "$lf" '
        .category_presets[] | select(.category==$c)
        | . as $g
        | (($g.actions // []) | length) as $n
        | "\($g.id)\t\($g[$lf] // $g.label_zh // $g.label_en // "")\t\($g.cmd // "")\t\($n)\t\($g.dangerous // false)"
      ' "$CATALOG_JSON")

      if ((${#gids[@]} == 0)); then
        echo "$(msg empty)"; break
      fi
      st=0
      menu_select back "$cat_title (${#gids[@]})" "$(msg hint_nav)" "${glabels[@]}" || st=$?
      case "$st" in
        2) return 2 ;;
        1) break ;; # back → chapters
        3) continue ;;
      esac
      if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#gids[@]})); then
        echo "$(msg invalid)"; sleep 0.6; continue
      fi
      local gidx=$((CHOICE - 1))
      local gid="${gids[$gidx]}"
      local n="${gnacts[$gidx]}"
      local template=""

      if [[ "$n" -le 1 ]]; then
        template="$(jq -r --argjson id "$gid" '
          .category_presets[] | select(.id == $id)
          | (.actions[0].cmd // .cmd // empty)
        ' "$CATALOG_JSON")"
      else
        while true; do
          local alabels=() acmds=() alabel acmd adang
          while IFS=$'\t' read -r alabel acmd adang; do
            [[ -n "$acmd" ]] || continue
            if [[ "$adang" == "true" ]]; then
              alabels+=("${danger_tag} ${alabel}  →  ${acmd}")
            else
              alabels+=("${alabel}  →  ${acmd}")
            fi
            acmds+=("$acmd")
          done < <(jq -r --argjson id "$gid" --arg lf "$lf" '
            .category_presets[] | select(.id == $id) | (.actions // [])[]
            | "\(.[$lf] // .label_zh // .label_en // "")\t\(.cmd)\t\(.dangerous // false)"
          ' "$CATALOG_JSON")

          st=0
          menu_select back "$(msg pick_cmd)" "$(msg hint_nav)" "${alabels[@]}" || st=$?
          case "$st" in
            2) return 2 ;;
            1) template=""; break ;; # back → groups
            3) continue ;;
          esac
          if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#acmds[@]})); then
            echo "$(msg invalid)"; sleep 0.6; continue
          fi
          template="${acmds[$((CHOICE - 1))]}"
          break
        done
        [[ -n "$template" ]] || continue
      fi

      [[ -n "$template" ]] || continue
      run_at_and_followup "$template"
      case "${NAV_AFTER_AT:-0}" in
        2) return 2 ;;
        1) break ;; # back → chapter list
      esac
    done
  done
}

menu_search() {
  # return 0 = back to main; return 2 = quit
  while true; do
    ask_line "$(msg search_ask)"
    local key="$ASK_VAL"
    key="${key//$'\r'/}"
    key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$key" in
      "") return 0 ;;
      b|B|back) return 0 ;;
      q|Q|quit|exit) return 2 ;;
    esac

    local tmp="${WORKDIR}/search.txt"
    spin_start "$(msg searching)"
    jq -r --arg k "$key" --arg lang "$UI_LANG" '
      ($k|ascii_downcase) as $q
      | .commands[]
      | select(
          ((.cmd//"") + " " + (.title//"") + " " + (.title_zh//"") + " " + (.title_en//""))
          | ascii_downcase | contains($q)
        )
      | [ .cmd,
          (if $lang=="en" then (.title // .title_en // .title_zh // "")
           else (.title_zh // .title // "") end) ]
      | @tsv
    ' "$CATALOG_JSON" | head -n 40 >"$tmp"
    spin_stop

    local cmds=() labels=() cmd desc st
    while IFS=$'\t' read -r cmd desc; do
      [[ -n "$cmd" ]] || continue
      cmds+=("$cmd")
      if cmd_is_dangerous "$cmd" >/dev/null; then
        labels+=("$(msg danger) ${cmd} — ${desc}")
      else
        labels+=("${cmd} — ${desc}")
      fi
    done <"$tmp"

    if ((${#cmds[@]} == 0)); then
      echo "$(msg search_none): $key"
      sleep 0.8
      continue
    fi

    while true; do
      st=0
      menu_select back "$(msg search_ask): $key" "$(msg hint_nav)" "${labels[@]}" || st=$?
      case "$st" in
        2) return 2 ;;
        1) break ;; # back → new search
        3) continue ;;
      esac
      if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || ((CHOICE < 1 || CHOICE > ${#cmds[@]})); then
        echo "$(msg invalid)"; sleep 0.6; continue
      fi
      run_at_and_followup "${cmds[$((CHOICE - 1))]}"
      case "${NAV_AFTER_AT:-0}" in
        2) return 2 ;;
        1) break ;; # back → search prompt
      esac
    done
  done
}

menu_custom() {
  # return 0 = back to main; return 2 = quit
  while true; do
    ask_line "$(msg custom_ask)"
    local cmd="$ASK_VAL"
    cmd="${cmd//$'\r'/}"
    cmd="$(printf '%s' "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$cmd" in
      "") return 0 ;;
      b|B|back) return 0 ;;
      q|Q|quit|exit) return 2 ;;
    esac
    run_at_and_followup "$cmd"
    case "${NAV_AFTER_AT:-0}" in
      2) return 2 ;;
      1) return 0 ;; # back → main
    esac
  done
}

menu_sms_all() {
  check_sms_deps || { pause; return 0; }
  local out="${WORKDIR}/sms_all.txt"
  ui_clear
  ui_header
  echo
  spin_start "$(msg reading_sms)"
  set +e
  mmcli_sms_dump_all "$SELECTED_MODEM_ID" >"$out" 2>&1
  set -e
  spin_stop
  log_file "mmcli messaging-list-sms" "$out"
  ui_clear
  ui_header
  echo
  echo "  $(msg mm5)"
  hr
  if [[ -s "$out" ]]; then cat "$out"; else echo "$(msg empty)"; fi
  hr
  pause
}

menu_sms_listen() {
  check_sms_deps || { pause; return 0; }
  ui_clear
  ui_header
  echo
  echo "  $(msg listen)"
  echo "  Modem: $SELECTED_MODEM_ID"
  hr
  INTERRUPTED=0
  local -A seen=()
  local id
  # Seed with already-known messages so we only print new ones.
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    seen["$id"]=1
  done < <(mmcli_sms_indices "$SELECTED_MODEM_ID")
  echo "  watching… (${#seen[@]} existing skipped)"
  echo
  set +e
  while [[ "${INTERRUPTED:-0}" -eq 0 ]]; do
    while IFS= read -r id; do
      [[ -n "$id" ]] || continue
      if [[ -z "${seen[$id]+x}" ]]; then
        seen["$id"]=1
        mmcli_sms_show "$id"
        echo
      fi
    done < <(mmcli_sms_indices "$SELECTED_MODEM_ID")
    sleep 2
  done
  set -e
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    INTERRUPTED=0
    echo
    echo "  $(msg int_back)"
  fi
  pause
}

menu_view_log() {
  ui_clear
  ui_header
  echo
  echo "  $(msg m_log)"
  hr
  if [[ -f "$LOG_FILE" ]]; then
    tail -n 80 "$LOG_FILE"
  else
    echo "$(msg empty)"
  fi
  hr
  pause
}

menu_clear_log() {
  if confirm_yn "$(msg clear_ask)"; then
    : >"$LOG_FILE"
    log "log cleared"
    echo "$(msg log_cleared)"
  fi
}

menu_language() {
  # return 0 = back/done; return 2 = quit
  local st=0
  menu_select back "$(msg lang)" "$(msg hint_nav)" "中文 (zh)" "English (en)" || st=$?
  case "$st" in
    2) return 2 ;;
    1|3) return 0 ;;
  esac
  case "$CHOICE" in
    1) UI_LANG=zh ;;
    2) UI_LANG=en ;;
    *) echo "$(msg invalid)"; return 0 ;;
  esac
  save_lang
  echo "$(msg lang_ok): $UI_LANG"
}

# Show mmcli output fullscreen then pause.
# Usage: mmcli_show TITLE [timeout_sec] -- mmcli args...
# If second arg is a number, it is the timeout; otherwise default 60s.
mmcli_show() {
  local title="$1"
  shift
  local tmo=60
  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    tmo="$1"
    shift
  fi
  local out="${WORKDIR}/mmcli_out.txt" rc=0
  ui_clear
  ui_header
  echo
  echo "  $title"
  echo "  >>> mmcli $*"
  echo
  spin_start "$(msg mm_running)"
  set +e
  timeout --foreground "${tmo}s" mmcli "$@" >"$out" 2>&1
  rc=$?
  set -e
  spin_stop
  log_file "mmcli $*" "$out"
  ui_clear
  ui_header
  echo
  echo "  $title"
  hr
  if [[ -s "$out" ]]; then
    cat "$out"
  else
    echo "(mmcli rc=$rc)"
  fi
  echo
  hr
  pause
}

mmcli_primary_sim_index() {
  local mid="${1:-$SELECTED_MODEM_ID}" path
  path="$(timeout --foreground 8s mmcli -m "$mid" 2>>"$LOG_FILE" |
    awk 'match($0, /\/SIM\/[0-9]+/) {
      s = substr($0, RSTART, RLENGTH)
      sub(/.*\//, "", s)
      print s
      exit
    }')"
  printf '%s' "$path"
}

menu_mmcli_sim() {
  [[ -n "${SELECTED_MODEM_ID:-}" ]] || { echo "$(msg need_modem)"; pause; return 0; }
  local sid
  sid="$(mmcli_primary_sim_index "$SELECTED_MODEM_ID")"
  if [[ -z "$sid" ]]; then
    echo "$(msg mm_no_sim)"
    pause
    return 0
  fi
  mmcli_show "$(msg mm2) (SIM/$sid)" -i "$sid"
}

menu_mmcli_signal() {
  [[ -n "${SELECTED_MODEM_ID:-}" ]] || { echo "$(msg need_modem)"; pause; return 0; }
  set +e
  timeout --foreground 8s mmcli -m "$SELECTED_MODEM_ID" --signal-setup=10 >/dev/null 2>>"$LOG_FILE"
  set -e
  sleep 1
  mmcli_show "$(msg mm3)" -m "$SELECTED_MODEM_ID" --signal-get
}

mmcli_require_modem() {
  [[ -n "${SELECTED_MODEM_ID:-}" ]] || { echo "$(msg need_modem)"; pause; return 1; }
  return 0
}

mmcli_op_modem() {
  # Usage: mmcli_op_modem TITLE [--danger] [timeout_sec] mmcli-args...
  local title="$1"
  shift
  local danger=0 tmo=""
  if [[ "${1:-}" == "--danger" ]]; then
    danger=1
    shift
  fi
  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    tmo="$1"
    shift
  fi
  mmcli_require_modem || return 0
  if [[ "$danger" -eq 1 ]]; then
    confirm_yn "$(msg mm_confirm_dang)" || { echo "$(msg cancelled)"; pause; return 0; }
  else
    confirm_yn "$(msg mm_confirm_op)" || { echo "$(msg cancelled)"; pause; return 0; }
  fi
  if [[ -n "$tmo" ]]; then
    mmcli_show "$title" "$tmo" -m "$SELECTED_MODEM_ID" "$@"
  else
    mmcli_show "$title" -m "$SELECTED_MODEM_ID" "$@"
  fi
}

menu_mmcli_send_sms() {
  mmcli_require_modem || return 0
  local to text create_out sid
  ask_line "$(msg mm_sms_to)" || return 0
  to="$ASK_VAL"
  [[ -n "$to" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  ask_line "$(msg mm_sms_text)" || return 0
  text="$ASK_VAL"
  [[ -n "$text" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  confirm_yn "$(msg mm_confirm_op)" || { echo "$(msg cancelled)"; pause; return 0; }

  create_out="${WORKDIR}/mmcli_sms_create.txt"
  set +e
  timeout --foreground 30s mmcli -m "$SELECTED_MODEM_ID" \
    --messaging-create-sms="number=${to},text=${text}" >"$create_out" 2>&1
  set -e
  log_file "mmcli create-sms" "$create_out"
  sid="$(awk 'match($0, /\/SMS\/[0-9]+/) {
    s = substr($0, RSTART, RLENGTH)
    sub(/.*\//, "", s)
    print s
    exit
  }' "$create_out")"
  if [[ -z "$sid" ]]; then
    ui_clear
    ui_header
    echo
    echo "  $(msg mop9)"
    hr
    cat "$create_out"
    hr
    pause
    return 0
  fi
  mmcli_show "$(msg mop9) (SMS/$sid)" -s "$sid" --send
}

menu_mmcli_delete_sms() {
  mmcli_require_modem || return 0
  local sid
  ask_line "$(msg mm_sms_id)" || return 0
  sid="$ASK_VAL"
  [[ -n "$sid" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  confirm_yn "$(msg mm_confirm_dang)" || { echo "$(msg cancelled)"; pause; return 0; }
  mmcli_show "$(msg mop10)" -m "$SELECTED_MODEM_ID" --messaging-delete-sms="$sid"
}

menu_mmcli_pin() {
  mmcli_require_modem || return 0
  local sid pin
  sid="$(mmcli_primary_sim_index "$SELECTED_MODEM_ID")"
  if [[ -z "$sid" ]]; then
    echo "$(msg mm_no_sim)"
    pause
    return 0
  fi
  ask_line "$(msg mm_pin_ask)" || return 0
  pin="$ASK_VAL"
  [[ -n "$pin" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  confirm_yn "$(msg mm_confirm_op)" || { echo "$(msg cancelled)"; pause; return 0; }
  mmcli_show "$(msg mop11)" -i "$sid" --pin="$pin"
}

menu_mmcli_puk() {
  mmcli_require_modem || return 0
  local sid pin puk
  sid="$(mmcli_primary_sim_index "$SELECTED_MODEM_ID")"
  if [[ -z "$sid" ]]; then
    echo "$(msg mm_no_sim)"
    pause
    return 0
  fi
  ask_line "$(msg mm_puk_ask)" || return 0
  puk="$ASK_VAL"
  ask_line "$(msg mm_pin_ask)" || return 0
  pin="$ASK_VAL"
  [[ -n "$puk" && -n "$pin" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  confirm_yn "$(msg mm_confirm_dang)" || { echo "$(msg cancelled)"; pause; return 0; }
  mmcli_show "$(msg mop12)" -i "$sid" --pin="$pin" --puk="$puk"
}

menu_mmcli_connect() {
  mmcli_require_modem || return 0
  local apn
  ask_line "$(msg mm_apn_ask)" || return 0
  apn="$ASK_VAL"
  [[ -n "$apn" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  confirm_yn "$(msg mm_confirm_op)" || { echo "$(msg cancelled)"; pause; return 0; }
  mmcli_show "$(msg mop5)" 120 -m "$SELECTED_MODEM_ID" --simple-connect="apn=${apn}"
}

menu_mmcli_factory() {
  mmcli_require_modem || return 0
  local code
  ask_line "$(msg mm_factory_code)" || return 0
  code="$ASK_VAL"
  [[ -n "$code" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  confirm_yn "$(msg mm_confirm_dang)" || { echo "$(msg cancelled)"; pause; return 0; }
  mmcli_show "$(msg mop4)" -m "$SELECTED_MODEM_ID" --factory-reset="$code"
}

menu_mmcli_ussd() {
  mmcli_require_modem || return 0
  local cmd
  ask_line "$(msg mm_ussd_ask)" || return 0
  cmd="$ASK_VAL"
  [[ -n "$cmd" ]] || { echo "$(msg cancelled)"; pause; return 0; }
  confirm_yn "$(msg mm_confirm_op)" || { echo "$(msg cancelled)"; pause; return 0; }
  mmcli_show "$(msg mop16)" 60 -m "$SELECTED_MODEM_ID" --3gpp-ussd-initiate="$cmd"
}

# returns: 0 = back, 2 = quit
menu_mmcli_query() {
  local st
  while true; do
    st=0
    menu_select back "$(msg mm_q_menu)" "$(msg hint_nav)" \
      "$(msg mm1)" \
      "$(msg mm2)" \
      "$(msg mm3)" \
      "$(msg mm4)" \
      "$(msg mm5)" \
      "$(msg mm6)" \
      "$(msg mm7)" \
      "$(msg mm8)" \
      "$(msg mm9)" \
      "$(msg mm10)" \
      "$(msg mm11)" \
      "$(msg mm12)" || st=$?
    case "$st" in
      2) return 2 ;;
      1) return 0 ;;
      3) continue ;;
    esac
    case "$CHOICE" in
      1)
        mmcli_require_modem || continue
        mmcli_show "$(msg mm1)" -m "$SELECTED_MODEM_ID"
        ;;
      2) menu_mmcli_sim ;;
      3) menu_mmcli_signal ;;
      4)
        mmcli_require_modem || continue
        mmcli_show "$(msg mm4)" -m "$SELECTED_MODEM_ID" --messaging-status
        ;;
      5) menu_sms_all ;;
      6) menu_sms_listen ;;
      7) mmcli_show "$(msg mm7)" -L ;;
      8) mmcli_show "$(msg mm8)" -B ;;
      9)
        mmcli_require_modem || continue
        mmcli_show "$(msg mm9)" -m "$SELECTED_MODEM_ID" --time
        ;;
      10)
        mmcli_require_modem || continue
        mmcli_show "$(msg mm10)" -m "$SELECTED_MODEM_ID" --location-get
        ;;
      11)
        mmcli_require_modem || continue
        mmcli_show "$(msg mm11)" -m "$SELECTED_MODEM_ID" --location-status
        ;;
      12)
        mmcli_require_modem || continue
        mmcli_show "$(msg mm12)" -m "$SELECTED_MODEM_ID" --3gpp-ussd-status
        ;;
      *) echo "$(msg invalid)"; sleep 0.6 ;;
    esac
  done
}

# returns: 0 = back, 2 = quit
menu_mmcli_actions() {
  local st
  while true; do
    st=0
    menu_select back "$(msg mm_op_menu)" "$(msg hint_nav)" \
      "$(msg mop1)" \
      "$(msg mop2)" \
      "$(msg mop3)" \
      "$(msg mop4)" \
      "$(msg mop5)" \
      "$(msg mop6)" \
      "$(msg mop7)" \
      "$(msg mop8)" \
      "$(msg mop9)" \
      "$(msg mop10)" \
      "$(msg mop11)" \
      "$(msg mop12)" \
      "$(msg mop13)" \
      "$(msg mop14)" \
      "$(msg mop15)" \
      "$(msg mop16)" \
      "$(msg mop17)" || st=$?
    case "$st" in
      2) return 2 ;;
      1) return 0 ;;
      3) continue ;;
    esac
    case "$CHOICE" in
      1) mmcli_op_modem "$(msg mop1)" -e ;;
      2) mmcli_op_modem "$(msg mop2)" -d ;;
      3) mmcli_op_modem "$(msg mop3)" --danger -r ;;
      4) menu_mmcli_factory ;;
      5) menu_mmcli_connect ;;
      6) mmcli_op_modem "$(msg mop6)" --simple-disconnect ;;
      7) mmcli_op_modem "$(msg mop7)" --3gpp-register-home ;;
      8) mmcli_op_modem "$(msg mop8)" 180 --3gpp-scan ;;
      9) menu_mmcli_send_sms ;;
      10) menu_mmcli_delete_sms ;;
      11) menu_mmcli_pin ;;
      12) menu_mmcli_puk ;;
      13) mmcli_op_modem "$(msg mop13)" --location-enable-gps-raw ;;
      14) mmcli_op_modem "$(msg mop14)" --location-disable-gps-raw ;;
      15)
        confirm_yn "$(msg mm_confirm_op)" || { echo "$(msg cancelled)"; pause; continue; }
        mmcli_show "$(msg mop15)" -S
        ;;
      16) menu_mmcli_ussd ;;
      17) mmcli_op_modem "$(msg mop17)" --3gpp-ussd-cancel ;;
      *) echo "$(msg invalid)"; sleep 0.6 ;;
    esac
  done
}

# returns: 0 = back, 2 = quit
menu_mmcli() {
  local st
  while true; do
    st=0
    menu_select back "$(msg mm_menu)" "$(msg hint_nav)" \
      "$(msg mm_q)" \
      "$(msg mm_op)" || st=$?
    case "$st" in
      2) return 2 ;;
      1) return 0 ;;
      3) continue ;;
    esac
    case "$CHOICE" in
      1)
        call_menu menu_mmcli_query
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      2)
        call_menu menu_mmcli_actions
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      *) echo "$(msg invalid)"; sleep 0.6 ;;
    esac
  done
}

# returns: 0 = back, 2 = quit
menu_at() {
  local st
  while true; do
    st=0
    menu_select back "$(msg at_menu)" "$(msg hint_nav)" \
      "$(msg at1)" \
      "$(msg at2)" \
      "$(msg at3)" \
      "$(msg at4)" || st=$?
    case "$st" in
      2) return 2 ;;
      1) return 0 ;;
      3) continue ;;
    esac
    case "$CHOICE" in
      1)
        call_menu menu_quick
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      2)
        call_menu menu_category
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      3)
        call_menu menu_search
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      4)
        call_menu menu_custom
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      *) echo "$(msg invalid)"; sleep 0.6 ;;
    esac
  done
}

# returns: 0 = back to modem select, 2 = quit
main_menu() {
  local st
  CALL_MENU_RC=0
  while true; do
    st=0
    menu_select back "$(msg main)" "$(msg hint_main)" \
      "$(msg m1)" \
      "$(msg m_at)" \
      "$(msg m_mmcli)" \
      "$(msg m_lang)" \
      "$(msg m_log)" \
      "$(msg m_log_clear)" || st=$?
    case "$st" in
      2) return 2 ;;
      1) return 0 ;; # b / Enter → modem select
      3) continue ;;
    esac
    case "$CHOICE" in
      1) return 0 ;; # refresh / switch modem
      2)
        call_menu menu_at
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      3)
        call_menu menu_mmcli
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      4)
        call_menu menu_language
        if [[ "${CALL_MENU_RC:-0}" -eq 2 ]]; then return 2; fi
        ;;
      5) menu_view_log ;;
      6) menu_clear_log ;;
      *) echo "$(msg invalid)"; sleep 0.6 ;;
    esac
  done
}

main() {
  parse_args "$@"
  if [[ "$PERSIST_LOG" -eq 1 ]]; then
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || {
      echo "cannot write log: $LOG_FILE" >&2
      exit 1
    }
  fi
  export QUICK_AT_LOG="$LOG_FILE"
  [[ -f "$CATALOG_JSON" ]] || die "$(msg no_catalog)"
  load_lang
  trap on_interrupt INT
  trap 'exit 143' TERM
  if [[ "$PERSIST_LOG" -eq 1 ]]; then
    log "===== start quick-at.sh CLI lang=$UI_LANG persist_log=$LOG_FILE ====="
  else
    log "===== start quick-at.sh CLI lang=$UI_LANG (session log only) ====="
  fi
  check_deps

  local prev_id="" prev_port="" prev_label="" prev_ports=()
  local in_session=0

  while true; do
    prev_id="$SELECTED_MODEM_ID"
    prev_port="$SELECTED_PORT"
    prev_label="$SELECTED_LABEL"
    prev_ports=("${MODEM_PORTS[@]+"${MODEM_PORTS[@]}"}")

    # Returning from main menu: clear header selection while re-picking
    if [[ "$in_session" -eq 1 ]]; then
      SELECTED_MODEM_ID=""
      SELECTED_PORT=""
      SELECTED_LABEL=""
      MODEM_PORTS=()
    fi

    local pick_st=0
    pick_modem || pick_st=$?
    if [[ $pick_st -eq 2 ]]; then
      break
    fi
    if [[ $pick_st -ne 0 ]]; then
      if [[ "$in_session" -eq 1 && -n "$prev_id" ]]; then
        # Cancel modem re-pick → restore previous and stay in main menu
        SELECTED_MODEM_ID="$prev_id"
        SELECTED_PORT="$prev_port"
        SELECTED_LABEL="$prev_label"
        MODEM_PORTS=("${prev_ports[@]+"${prev_ports[@]}"}")
      else
        break
      fi
    else
      local port_st=0
      pick_port || port_st=$?
      if [[ $port_st -ne 0 ]]; then
        if [[ "$in_session" -eq 1 && -n "$prev_id" && "$prev_id" != "$SELECTED_MODEM_ID" ]]; then
          SELECTED_MODEM_ID="$prev_id"
          SELECTED_PORT="$prev_port"
          SELECTED_LABEL="$prev_label"
          MODEM_PORTS=("${prev_ports[@]+"${prev_ports[@]}"}")
        else
          # No port / back → stay on modem select
          continue
        fi
      fi
    fi

    in_session=1
    local mm_st=0
    main_menu || mm_st=$?
    # 0 = back to modem select; 2 = quit; anything else = modem select (never hard-quit)
    if [[ $mm_st -eq 2 ]]; then
      break
    fi
  done
  echo "$(msg bye)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
