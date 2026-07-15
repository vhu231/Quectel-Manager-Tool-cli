#!/usr/bin/env python3
"""Regroup category_presets into group→actions (like quick_presets) and regenerate docs."""
from __future__ import annotations

import json
import re
from collections import OrderedDict
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CATALOG = ROOT / "at_catalog.json"
DOC_ZH = ROOT / "AT_COMMANDS_ZH.md"
DOC_EN = ROOT / "AT_COMMANDS_EN.md"

# Known stems: replace/expand actions to match quick menu semantics
EXPAND: dict[str, dict] = {
    'AT+QCFG="ims"': {
        "label_zh": "IMS/VoLTE 配置",
        "label_en": "IMS/VoLTE config",
        "actions": [
            {
                "label_zh": "强制开启 IMS/VoLTE 能力",
                "label_en": "Force enable IMS/VoLTE",
                "cmd": 'AT+QCFG="ims",1',
                "needs_reboot": True,
                "notes_zh": "强制开 IMS；需重启生效。",
                "notes_en": "Force enable IMS; reboot required.",
            },
            {
                "label_zh": "恢复默认 IMS（跟随 MBN）",
                "label_en": "Restore default IMS (follow MBN)",
                "cmd": 'AT+QCFG="ims",0',
                "needs_reboot": True,
                "notes_zh": "跟随 MBN 默认；需重启生效。",
                "notes_en": "Follow MBN default; reboot required.",
            },
            {
                "label_zh": "强制关闭 IMS",
                "label_en": "Force disable IMS",
                "cmd": 'AT+QCFG="ims",2',
                "needs_reboot": True,
                "notes_zh": "强制关（不是 0）；需重启生效。",
                "notes_en": "Force off (not 0); reboot required.",
            },
            {
                "label_zh": "查询 IMS/VoLTE 配置",
                "label_en": "Query IMS/VoLTE config",
                "cmd": 'AT+QCFG="ims"',
                "needs_reboot": False,
                "notes_zh": "返回 ims_conf,volte_cap。",
                "notes_en": "Returns ims_conf,volte_cap.",
            },
        ],
    },
    'AT+QCFG="usbnet"': {
        "label_zh": "USB 网卡模式",
        "label_en": "USB net mode",
        "actions": [
            {
                "label_zh": "网卡改为 QMI/RmNet",
                "label_en": "Set USB net to QMI/RmNet",
                "cmd": 'AT+QCFG="usbnet",0',
                "needs_reboot": True,
            },
            {
                "label_zh": "网卡改为 ECM",
                "label_en": "Set USB net to ECM",
                "cmd": 'AT+QCFG="usbnet",1',
                "needs_reboot": True,
            },
            {
                "label_zh": "网卡改为 MBIM",
                "label_en": "Set USB net to MBIM",
                "cmd": 'AT+QCFG="usbnet",2',
                "needs_reboot": True,
            },
            {
                "label_zh": "网卡改为 RNIDS",
                "label_en": "Set USB net to RNIDS",
                "cmd": 'AT+QCFG="usbnet",3',
                "needs_reboot": True,
            },
            {
                "label_zh": "查询网卡模式",
                "label_en": "Query USB net mode",
                "cmd": 'AT+QCFG="usbnet"',
                "needs_reboot": False,
            },
        ],
    },
    "AT+CFUN": {
        "label_zh": "模组功能级 (CFUN)",
        "label_en": "Module functionality (CFUN)",
        "actions": [
            {
                "label_zh": "查询功能级",
                "label_en": "Query functionality",
                "cmd": "AT+CFUN",
                "needs_reboot": False,
            },
            {
                "label_zh": "最小功能",
                "label_en": "Minimum functionality",
                "cmd": "AT+CFUN=0",
                "needs_reboot": False,
            },
            {
                "label_zh": "全功能",
                "label_en": "Full functionality",
                "cmd": "AT+CFUN=1",
                "needs_reboot": False,
            },
            {
                "label_zh": "关闭射频（类飞行模式）",
                "label_en": "RF off (airplane-like)",
                "cmd": "AT+CFUN=4",
                "needs_reboot": False,
            },
            {
                "label_zh": "全功能并复位模组",
                "label_en": "Full functionality + reset",
                "cmd": "AT+CFUN=1,1",
                "needs_reboot": False,
                "notes_zh": "复位模组，使需重启的配置生效。",
                "notes_en": "Reset module to apply pending config.",
            },
        ],
    },
}


def norm_family(cmd: str) -> str:
    """Group key: QCFG keeps quoted key; others use AT+NAME / AT&X / ATx."""
    cmd = (cmd or "").strip()
    m = re.match(r'^(AT\+QCFG="[^"]+")', cmd, re.I)
    if m:
        # normalize key to lowercase inside quotes for stable matching
        key = re.sub(
            r'AT\+QCFG="([^"]+)"',
            lambda mo: f'AT+QCFG="{mo.group(1).lower()}"',
            m.group(1),
            flags=re.I,
        )
        return key
    m = re.match(r"^(AT\+[A-Za-z0-9]+)", cmd, re.I)
    if m:
        return "AT+" + m.group(1)[3:].upper()
    m = re.match(r"^(AT[&A-Za-z0-9]+)", cmd, re.I)
    if m:
        return m.group(1).upper()
    return cmd


def item_to_action(it: dict) -> dict:
    a = {
        "label_zh": it.get("label_zh") or it.get("label_en") or it.get("cmd"),
        "label_en": it.get("label_en") or it.get("label_zh") or it.get("cmd"),
        "cmd": it["cmd"],
        "dangerous": bool(it.get("dangerous")),
        "needs_reboot": bool(it.get("needs_reboot")),
    }
    for k in ("notes_zh", "notes_en", "notes", "ref", "section", "prompt"):
        if it.get(k):
            a[k] = it[k]
    return a


def regroup_presets(presets: list[dict]) -> list[dict]:
    # Preserve category order by first-seen family within each category stream
    # Process in original order; group by (category, family)
    buckets: OrderedDict[tuple[str, str], list[dict]] = OrderedDict()
    meta: dict[tuple[str, str], dict] = {}

    for it in presets:
        cat = it.get("category") or ""
        fam = norm_family(it.get("cmd") or "")
        key = (cat, fam)
        if key not in buckets:
            buckets[key] = []
            meta[key] = {
                "id": it["id"],
                "category": cat,
                "source": it.get("source"),
                "ref": it.get("ref") or "",
                "section": it.get("section") or "",
                "dangerous": False,
            }
        buckets[key].append(it)
        if it.get("dangerous"):
            meta[key]["dangerous"] = True
        raw = (it.get("cmd") or "").strip()
        # Prefer exact family match (parent / query form) for group labels
        if raw == fam or raw.rstrip("?").upper() == fam.upper():
            meta[key]["label_zh"] = it.get("label_zh")
            meta[key]["label_en"] = it.get("label_en")
            meta[key]["ref"] = it.get("ref") or meta[key]["ref"]
            meta[key]["section"] = it.get("section") or meta[key]["section"]
            meta[key]["id"] = it["id"]  # prefer parent id

    out: list[dict] = []
    for key, items in buckets.items():
        cat, fam = key
        m = meta[key]
        actions = [item_to_action(x) for x in items]

        # Deduplicate by cmd (keep first)
        seen = set()
        deduped = []
        for a in actions:
            c = a["cmd"]
            if c in seen:
                continue
            seen.add(c)
            deduped.append(a)
        actions = deduped

        # Apply known expansions (replace actions + labels)
        exp = EXPAND.get(fam)
        if exp:
            actions = deepcopy(exp["actions"])
            label_zh = exp["label_zh"]
            label_en = exp["label_en"]
        else:
            label_zh = m.get("label_zh") or items[0].get("label_zh") or fam
            label_en = m.get("label_en") or items[0].get("label_en") or fam
            # If multiple siblings without a clean parent label, use family as title
            if len(actions) > 1 and not m.get("label_zh"):
                label_zh = fam
                label_en = fam

        group = {
            "id": m["id"],
            "category": cat,
            "label_zh": label_zh,
            "label_en": label_en,
            "cmd": fam,
            "ref": m.get("ref") or "",
            "section": m.get("section") or "",
            "source": m.get("source") or "",
            "dangerous": bool(m.get("dangerous")) or any(a.get("dangerous") for a in actions),
            "actions": actions,
        }
        out.append(group)
    return out


def rebuild_commands_from_groups(groups: list[dict], old_commands: list[dict]) -> list[dict]:
    """Keep search index covering every executable action cmd."""
    # Index old by normalized cmd for title reuse
    old_by = {}
    for c in old_commands:
        old_by[norm_family(c.get("cmd", "")) + "\0" + (c.get("cmd") or "")] = c
        old_by[c.get("cmd") or ""] = c

    new = []
    for g in groups:
        for a in g.get("actions") or []:
            cmd = a["cmd"]
            prev = old_by.get(cmd) or {}
            new.append(
                {
                    "cmd": cmd,
                    "title": prev.get("title") or a.get("label_en") or a.get("label_zh") or cmd,
                    "title_zh": a.get("label_zh") or prev.get("title_zh") or "",
                    "title_en": a.get("label_en") or prev.get("title_en") or "",
                    "source": g.get("source") or prev.get("source") or "",
                    "section": a.get("section") or g.get("section") or prev.get("section") or "",
                    "category": g.get("category") or prev.get("category") or "",
                    "daily": False,
                    "needs_reboot": bool(a.get("needs_reboot")),
                    "dangerous": bool(a.get("dangerous") or g.get("dangerous")),
                }
            )
    return new


def md_escape(s: str) -> str:
    return (s or "").replace("|", "\\|")


def render_browse_zh(data: dict) -> str:
    cats = data.get("categories") or {}
    groups = data.get("category_presets") or []
    by_cat: dict[str, list] = {}
    for g in groups:
        by_cat.setdefault(g["category"], []).append(g)

    sources = (data.get("browse") or {}).get("sources") or []
    lines = [
        "## 浏览 AT 目录（组 → 动作）",
        "",
        "路径：章节（AT / QCFG / QSIMCFG 合并）→ **命令组** → **动作**。多动作组先选组再选具体 AT；单动作组直接执行。危险项标 `[危险]`。",
        "",
    ]

    src_title = {"at": "AT 手册 V2.2", "qcfg": "QCFG V1.6", "qsimcfg": "QSIMCFG V1.0"}
    for src in sources:
        sid = src["id"]
        lines.append(f"### {src_title.get(sid, src.get('zh') or sid)}")
        lines.append("")
        # chapters for this source sorted by order
        chapter_keys = sorted(
            [k for k, v in cats.items() if v.get("source") == sid],
            key=lambda k: cats[k].get("order", 0),
        )
        for ck in chapter_keys:
            cv = cats[ck]
            title = cv.get("zh") or cv.get("en") or ck
            lines.append(f"#### {title}")
            lines.append("")
            glist = by_cat.get(ck) or []
            if not glist:
                lines.append("（无）")
                lines.append("")
                continue
            for g in glist:
                dang = " `[危险]`" if g.get("dangerous") else ""
                acts = g.get("actions") or []
                ref = g.get("ref") or ""
                if len(acts) <= 1:
                    a = acts[0] if acts else {}
                    cmd = a.get("cmd") or g.get("cmd") or ""
                    lab = a.get("label_zh") or g.get("label_zh") or ""
                    lines.append(
                        f"- **{md_escape(lab)}**{dang} → `{cmd}`"
                        + (f" · {ref}" if ref else "")
                    )
                else:
                    lines.append(
                        f"- **{md_escape(g.get('label_zh') or g.get('cmd'))}**{dang} — `{g.get('cmd')}`"
                        + (f" · {ref}" if ref else "")
                    )
                    for a in acts:
                        ad = " `[危险]`" if a.get("dangerous") else ""
                        lines.append(
                            f"  - {md_escape(a.get('label_zh') or '')}{ad} → `{a.get('cmd')}`"
                        )
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_browse_en(data: dict) -> str:
    cats = data.get("categories") or {}
    groups = data.get("category_presets") or []
    by_cat: dict[str, list] = {}
    for g in groups:
        by_cat.setdefault(g["category"], []).append(g)

    sources = (data.get("browse") or {}).get("sources") or []
    lines = [
        "## Browse AT catalog (group → action)",
        "",
        "Path: Chapter (AT / QCFG / QSIMCFG merged) → **group** → **action**. Multi-action groups open a submenu; single-action runs immediately. Dangerous items marked `[DANGER]`.",
        "",
    ]
    src_title = {"at": "AT Manual V2.2", "qcfg": "QCFG V1.6", "qsimcfg": "QSIMCFG V1.0"}
    for src in sources:
        sid = src["id"]
        lines.append(f"### {src_title.get(sid, src.get('en') or sid)}")
        lines.append("")
        chapter_keys = sorted(
            [k for k, v in cats.items() if v.get("source") == sid],
            key=lambda k: cats[k].get("order", 0),
        )
        for ck in chapter_keys:
            cv = cats[ck]
            title = cv.get("en") or cv.get("zh") or ck
            lines.append(f"#### {title}")
            lines.append("")
            glist = by_cat.get(ck) or []
            if not glist:
                lines.append("(empty)")
                lines.append("")
                continue
            for g in glist:
                dang = " `[DANGER]`" if g.get("dangerous") else ""
                acts = g.get("actions") or []
                ref = g.get("ref") or ""
                if len(acts) <= 1:
                    a = acts[0] if acts else {}
                    cmd = a.get("cmd") or g.get("cmd") or ""
                    lab = a.get("label_en") or g.get("label_en") or ""
                    lines.append(
                        f"- **{md_escape(lab)}**{dang} → `{cmd}`"
                        + (f" · {ref}" if ref else "")
                    )
                else:
                    lines.append(
                        f"- **{md_escape(g.get('label_en') or g.get('cmd'))}**{dang} — `{g.get('cmd')}`"
                        + (f" · {ref}" if ref else "")
                    )
                    for a in acts:
                        ad = " `[DANGER]`" if a.get("dangerous") else ""
                        lines.append(
                            f"  - {md_escape(a.get('label_en') or '')}{ad} → `{a.get('cmd')}`"
                        )
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def replace_section(text: str, start_marker: str, next_markers: list[str], new_body: str) -> str:
    i = text.find(start_marker)
    if i < 0:
        raise SystemExit(f"marker not found: {start_marker}")
    end = len(text)
    for m in next_markers:
        j = text.find(m, i + len(start_marker))
        if j >= 0:
            end = min(end, j)
    return text[:i] + new_body + "\n" + text[end:]


def render_dangerous_zh(data: dict) -> str:
    lines = ["## 危险命令", "", "| 用途 | 命令 | 说明 | 出处 |", "|------|------|------|------|"]
    for d in data.get("dangerous") or []:
        lines.append(
            f"| {md_escape(d.get('label_zh') or d.get('label') or '')} | `{d.get('cmd')}` | {md_escape(d.get('notes_zh') or d.get('notes') or '')} | {md_escape(d.get('ref') or '')} |"
        )
    return "\n".join(lines) + "\n"


def render_dangerous_en(data: dict) -> str:
    lines = ["## Dangerous commands", "", "| Purpose | Command | Notes | Ref |", "|---------|---------|-------|-----|"]
    for d in data.get("dangerous") or []:
        lines.append(
            f"| {md_escape(d.get('label_en') or d.get('label') or '')} | `{d.get('cmd')}` | {md_escape(d.get('notes_en') or d.get('notes') or '')} | {md_escape(d.get('ref') or '')} |"
        )
    return "\n".join(lines) + "\n"


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    old_presets = data.get("category_presets") or []
    already = bool(old_presets) and all(isinstance(p.get("actions"), list) for p in old_presets)

    if already:
        groups = old_presets
        print(f"category_presets already grouped: {len(groups)} groups (docs refresh only)")
    else:
        old_n = len(old_presets)
        groups = regroup_presets(old_presets)
        data["category_presets"] = groups
        data["commands"] = rebuild_commands_from_groups(groups, data.get("commands") or [])
        if isinstance(data.get("version"), int):
            data["version"] = data["version"] + 1
        elif "version" not in data:
            data["version"] = 5
        CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        multi = sum(1 for g in groups if len(g.get("actions") or []) > 1)
        print(f"category_presets: {old_n} flat → {len(groups)} groups ({multi} multi-action)")
        print(f"commands index: {len(data['commands'])} entries")

    # Docs: replace browse + dangerous sections
    zh = DOC_ZH.read_text(encoding="utf-8")
    en = DOC_EN.read_text(encoding="utf-8")

    zh_browse = render_browse_zh(data)
    en_browse = render_browse_en(data)
    zh_dang = render_dangerous_zh(data)
    en_dang = render_dangerous_en(data)

    zh = replace_section(zh, "## 浏览 AT 目录", ["## 危险命令", "## Dangerous"], zh_browse)
    # after browse comes dangerous
    if "## 危险命令" in zh:
        zh = replace_section(zh, "## 危险命令", [], zh_dang)
    else:
        zh = zh.rstrip() + "\n\n" + zh_dang

    en = replace_section(en, "## Browse AT catalog", ["## Dangerous commands", "## 危险"], en_browse)
    if "## Dangerous commands" in en:
        en = replace_section(en, "## Dangerous commands", [], en_dang)
    else:
        en = en.rstrip() + "\n\n" + en_dang

    # Update intro lines about browse path
    zh = zh.replace(
        "路径：手册 → 章节 → 命令。危险项标 `[危险]`，仍可执行（二次确认）。",
        "路径：手册 → 章节 → 命令组 → 动作。危险项标 `[危险]`，仍可执行（二次确认）。",
    )
    en = en.replace(
        "Path: Manual → Chapter → Command. Dangerous items marked `[DANGER]` (confirm to run).",
        "Path: Manual → Chapter → Group → Action. Dangerous items marked `[DANGER]` (confirm to run).",
    )

    DOC_ZH.write_text(zh, encoding="utf-8")
    DOC_EN.write_text(en, encoding="utf-8")
    print("docs updated:", DOC_ZH.name, DOC_EN.name)


if __name__ == "__main__":
    main()
