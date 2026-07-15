# Quectel AT 命令中文用途

脚本 `quick-at.sh` 为 **CLI**（无 dialog TUI），支持中/英（菜单「切换语言」或本会话 `--lang zh|en` / `QUICK_AT_LANG`）。
默认**不落盘用户数据**；仅当启动带 `--log` 时保存日志：
- `./quick-at.sh --log` → 同目录 `quick-at.log`
- `./quick-at.sh --log /path/to/file.log` → 指定路径
每条 AT 响应下方附带 PDF 手册参数注释。英文版见 [AT_COMMANDS_EN.md](AT_COMMANDS_EN.md)。
操作：输入数字选择；`b` 返回；`q` 退出。Modem 首页直接回车=刷新。
等待时显示 `...` 动画；每次操作后清屏，状态栏置顶（沉浸式类 TUI）。

## 手册来源

- `at`: AT Manual V2.2 — `Quectel_EC2xEG2xEG9xEM05_Series_AT_Commands_Manual_V2.2.pdf`
- `qcfg`: QCFG V1.6 — `Quectel_EC2xEG2xEG9xEM05_Series_QCFG_AT_Commands_Manual_V1.6.pdf`
- `qsimcfg`: QSIMCFG V1.0 — `Quectel_EC2xEG2xEG9xEM05系列_QSIMCFG_AT命令手册_V1.0.pdf`

## 官方语义（IMS / usbnet）

- `AT+QCFG="ims"`：`0` 跟随 MBN；`1` 强制开 IMS；`2` 强制关 IMS；**重启后生效**。
- `AT+QCFG="usbnet"`：`0` RmNet(QMI/NDIS)；`1` ECM；`2` MBIM；`3` RNIDS；**重启后生效**。
- `AT+QCFG="volte_disable"` 与 `ims` 不同，日常以 `ims` 为准。

## 日常常用（快捷菜单，分组）

先选命令组，再选具体动作（单动作组直接执行）。

### 1 IMS/VoLTE 配置 — `AT+QCFG="ims"`

| 动作 | 命令 | 说明 | 出处 |
|------|------|------|------|
| 强制开启 IMS/VoLTE 能力 | `AT+QCFG="ims",1` | 强制开 IMS；需重启生效。 | QCFG V1.6 §7.6 |
| 恢复默认 IMS（跟随 MBN） | `AT+QCFG="ims",0` | 使用 MBN 默认；需重启生效。 | QCFG V1.6 §7.6 |
| 强制关闭 IMS | `AT+QCFG="ims",2` | 强制关（不是 0）；需重启生效。 | QCFG V1.6 §7.6 |
| 查询 IMS/VoLTE 配置 | `AT+QCFG="ims"` | 返回 ims_conf,volte_cap。 | QCFG V1.6 §7.6 |

### 2 USB 网卡模式 — `AT+QCFG="usbnet"`

| 动作 | 命令 | 说明 | 出处 |
|------|------|------|------|
| 网卡改为 QMI/RmNet | `AT+QCFG="usbnet",0` | 0=RmNet 1=ECM 2=MBIM 3=RNIDS；需重启。 | QCFG V1.6 §9.1 |
| 网卡改为 ECM | `AT+QCFG="usbnet",1` | 需重启生效。 | QCFG V1.6 §9.1 |
| 网卡改为 MBIM | `AT+QCFG="usbnet",2` | 需重启生效。 | QCFG V1.6 §9.1 |
| 网卡改为 RNIDS | `AT+QCFG="usbnet",3` | 需重启生效。 | QCFG V1.6 §9.1 |
| 查询网卡模式 | `AT+QCFG="usbnet"` | 读取当前 net 值。 | QCFG V1.6 §9.1 |

### 3–4 其他

| ID | 中文用途 | 命令 | 说明 | 出处 |
|----|----------|------|------|------|
| 3 | 重启并应用配置 | `AT+CFUN=1,1` | 使 ims/usbnet 等配置生效。 | AT Manual V2.2 |
| 4 | 修改 IMEI (EGMR) | `AT+EGMR=1,7,"<IMEI>"` | 弹出输入 IMEI；危险，通常需重启。 | Quectel EGMR |

## 浏览 AT 目录（组 → 动作）

路径：章节（AT / QCFG / QSIMCFG 合并）→ **命令组** → **动作**。多动作组先选组再选具体 AT；单动作组直接执行。危险项标 `[危险]`。

### AT 手册 V2.2

#### 2 通用命令

- **设置命令回显** → `ATE` · AT Manual V2.2 §2.x
- **查厂商/型号/版本摘要** → `ATI` · AT Manual V2.2 §2.x
- **恢复默认配置** → `ATZ` · AT Manual V2.2 §2.x
- **查询厂商识别信息** → `AT+GMI` · AT Manual V2.2 §2.2
- **查询型号识别信息** → `AT+GMM` · AT Manual V2.2 §2.3
- **查询 TA 固件版本** → `AT+GMR` · AT Manual V2.2 §2.4
- **查询厂商识别信息** → `AT+CGMI` · AT Manual V2.2 §2.5
- **查询模块型号** → `AT+CGMM` · AT Manual V2.2 §2.6
- **查询 MT 固件版本** → `AT+CGMR` · AT Manual V2.2 §2.7
- **查询 IMEI 与序列号** → `AT+GSN` · AT Manual V2.2 §2.8
- **查 IMEI** → `AT+CGSN` · AT Manual V2.2 §2.9
- **恢复出厂默认设置** `[危险]` → `AT&F` · AT Manual V2.2 §2.10
- **显示当前配置** → `AT&V` · AT Manual V2.2 §2.11
- **保存当前设置到用户配置** → `AT&W` · AT Manual V2.2 §2.12
- **模组功能级 (CFUN)** — `AT+CFUN` · AT Manual V2.2 §2.22
  - 查询功能级 → `AT+CFUN`
  - 最小功能 → `AT+CFUN=0`
  - 全功能 → `AT+CFUN=1`
  - 关闭射频（类飞行模式） → `AT+CFUN=4`
  - 全功能并复位模组 → `AT+CFUN=1,1`
- **设置错误上报格式（0关/1数字码/2详细）** → `AT+CMEE` · AT Manual V2.2 §2.23
- **选择 TE 字符集** → `AT+CSCS` · AT Manual V2.2 §2.24
- **配置 URC 上报选项** → `AT+QURCCFG` · AT Manual V2.2 §2.25
- **配置 to 报告 Specified URC** → `AT+QAPRDYIND` · AT Manual V2.2 §2.26
- **调试串口配置** → `AT+QDIAGPORT` · AT Manual V2.2 §2.27

#### 3 串口控制命令

- **设置 DCD 功能模式** → `AT&C` · AT Manual V2.2 §3.1
- **设置 DTR 功能模式** → `AT&D` · AT Manual V2.2 §3.2
- **设置 TE-TA 本地数据流控** → `AT+IFC` · AT Manual V2.2 §3.3
- **设置 TE-TA 字符帧格式** → `AT+ICF` · AT Manual V2.2 §3.4
- **设置 TE-TA 固定波特率** → `AT+IPR` · AT Manual V2.2 §3.5
- **恢复 RI 到非激活状态** → `AT+QRIR` · AT Manual V2.2 §3.6

#### 4 状态控制命令

- **查询设备活动状态** → `AT+CPAS` · AT Manual V2.2 §4.1
- **查扩展错误原因** → `AT+CEER` · AT Manual V2.2 §4.2
- **URC 上报配置** → `AT+QINDCFG` · AT Manual V2.2 §4.3
- **MBN 文件配置** `[危险]` — `AT+QMBNCFG` · AT Manual V2.2 §4.4
  - MBN 文件配置 → `AT+QMBNCFG`
  - 查询 Imported MBN File List → `AT+QMBNCFG="List"`
  - 选择 Imported MBN File → `AT+QMBNCFG="Select"`
  - 去激活 MBN 文件 → `AT+QMBNCFG="Deactivate"`
  - Auto 选择 Whetherto Activate MBN File → `AT+QMBNCFG="AutoSel"`
  - 添加 MBN 文件 → `AT+QMBNCFG="Add"`
  - 删除 MBN File `[危险]` → `AT+QMBNCFG="Delete"`

#### 5 (U)SIM 相关命令

- **查 IMSI** → `AT+CIMI` · AT Manual V2.2 §5.1
- **设施锁（SIM/网络锁）** → `AT+CLCK` · AT Manual V2.2 §5.2
- **查 PIN 状态** → `AT+CPIN` · AT Manual V2.2 §5.3
- **修改密码** → `AT+CPWD` · AT Manual V2.2 §5.4
- **通用 (U)SIM 访问** → `AT+CSIM` · AT Manual V2.2 §5.5
- **受限 (U)SIM 访问** → `AT+CRSM` · AT Manual V2.2 §5.6
- **显示 SIM 卡 ICCID** → `AT+QCCID` · AT Manual V2.2 §5.7
- **显示 PIN 剩余重试次数** → `AT+QPINC` · AT Manual V2.2 §5.8
- **查询 (U)SIM 卡初始化状态** → `AT+QINISTAT` · AT Manual V2.2 §5.9
- **(U)SIM 卡检测** → `AT+QSIMDET` · AT Manual V2.2 §5.10
- **（U）SIM 插拔状态上报** → `AT+QSIMSTAT` · AT Manual V2.2 §5.11
- **切换 (U)SIM 卡槽** `[危险]` → `AT+QDSIM` · AT Manual V2.2 §5.12
- **固定 (U)SIM 卡供电电压** → `AT+QSIMVOL` · AT Manual V2.2 §5.13
- **打开逻辑通道** → `AT+CCHO` · AT Manual V2.2 §5.14
- **UICC 逻辑通道访问** → `AT+CGLA` · AT Manual V2.2 §5.15
- **关闭逻辑通道** → `AT+CCHC` · AT Manual V2.2 §5.16

#### 6 网络服务命令

- **查注册运营商** → `AT+COPS` · AT Manual V2.2 §6.1
- **查 CS 注册** → `AT+CREG` · AT Manual V2.2 §6.2
- **查信号** → `AT+CSQ` · AT Manual V2.2 §6.3
- **报告信号质量** → `AT+QCSQ` · AT Manual V2.2 §6.4
- **首选运营商列表** → `AT+CPOL` · AT Manual V2.2 §6.5
- **读取运营商名称** → `AT+COPN` · AT Manual V2.2 §6.6
- **自动时区更新** → `AT+CTZU` · AT Manual V2.2 §6.7
- **时区上报** → `AT+CTZR` · AT Manual V2.2 §6.8
- **查网络同步时间** → `AT+QLTS` · AT Manual V2.2 §6.9
- **查移远网络信息** → `AT+QNWINFO` · AT Manual V2.2 §6.10
- **查注册网络名** → `AT+QSPN` · AT Manual V2.2 §6.11
- **查询网络信息 of RATs** → `AT+QNETINFO` · AT Manual V2.2 §6.12
- **LTE 锁频/锁小区配置** → `AT+QNWLOCK="common/lte"` · AT Manual V2.2 §6.13
- **手动频段扫描配置** — `AT+QOPSCFG` · AT Manual V2.2 §6.14
  - 手动频段扫描配置 → `AT+QOPSCFG`
  - 配置 Bandstobe Scannedin 2G/3G/4G → `AT+QOPSCFG="scancontrol"`
  - 启用/禁用 to 显示 RSSIin LTE → `AT+QOPSCFG="displayrssi"`
  - 启用/禁用 to 显示 Bandwidthin LTE → `AT+QOPSCFG="displaybw"`
  - 设置 Maximum Durationfor Manual Band Scan → `AT+QOPSCFG="guard_timer"`
- **频段扫描** → `AT+QOPS` · AT Manual V2.2 §6.15
- **FPLMN 配置** → `AT+QFPLMNCFG` · AT Manual V2.2 §6.16
- **工程模式（网络信息）** → `AT+QENG` · AT Manual V2.2 §6.17
- **指示器控制** → `AT+CIND` · AT Manual V2.2 §6.18

#### 7 呼叫相关命令

- **语音挂断控制** → `AT+CVHU` · AT Manual V2.2 §7.4
- **挂断语音通话** → `AT+CHUP` · AT Manual V2.2 §7.5
- **选择承载业务类型** → `AT+CBST` · AT Manual V2.2 §7.14
- **选择地址类型** → `AT+CSTA` · AT Manual V2.2 §7.15
- **列出当前通话** → `AT+CLCC` · AT Manual V2.2 §7.16
- **业务上报控制** → `AT+CR` · AT Manual V2.2 §7.17
- **来电指示结果码格式** → `AT+CRC` · AT Manual V2.2 §7.18
- **无线链路协议参数** → `AT+CRLP` · AT Manual V2.2 §7.19
- **配置紧急呼叫号码** → `AT+QECCNUM` · AT Manual V2.2 §7.20
- **以指定释放原因挂断** → `AT+QHUP` · AT Manual V2.2 §7.21
- **挂断 VoLTE 会议中某路通话** → `AT+QCHLDIPMPTY` · AT Manual V2.2 §7.22

#### 8 电话簿命令

- **本机号码** → `AT+CNUM` · AT Manual V2.2 §8.1
- **查找电话簿条目** → `AT+CPBF` · AT Manual V2.2 §8.2
- **读取电话簿条目** → `AT+CPBR` · AT Manual V2.2 §8.3
- **选择电话簿存储** → `AT+CPBS` · AT Manual V2.2 §8.4
- **写入电话簿条目** → `AT+CPBW` · AT Manual V2.2 §8.5

#### 9 短信命令

- **选择短信业务** → `AT+CSMS` · AT Manual V2.2 §9.1
- **设置短信格式（PDU/文本）** → `AT+CMGF` · AT Manual V2.2 §9.2
- **短信中心号码** → `AT+CSCA` · AT Manual V2.2 §9.3
- **短信首选存储位置** → `AT+CPMS` · AT Manual V2.2 §9.4
- **删除短信** `[危险]` → `AT+CMGD` · AT Manual V2.2 §9.5
- **列出短信** → `AT+CMGL` · AT Manual V2.2 §9.6
- **读取短信** → `AT+CMGR` · AT Manual V2.2 §9.7
- **发送短信** `[危险]` → `AT+CMGS` · AT Manual V2.2 §9.8
- **连续发送多条短信** → `AT+CMMS` · AT Manual V2.2 §9.9
- **写短信到存储** → `AT+CMGW` · AT Manual V2.2 §9.10
- **从存储发送短信** `[危险]` → `AT+CMSS` · AT Manual V2.2 §9.11
- **新消息确认** → `AT+CNMA` · AT Manual V2.2 §9.12
- **配置短信事件上报（CNMI）** → `AT+CNMI` · AT Manual V2.2 §9.13
- **选择小区广播消息类型** → `AT+CSCB` · AT Manual V2.2 §9.14
- **显示短信文本模式参数** → `AT+CSDH` · AT Manual V2.2 §9.15
- **设置短信文本模式参数** → `AT+CSMP` · AT Manual V2.2 §9.16
- **发送长短信** `[危险]` → `AT+QCMGS` · AT Manual V2.2 §9.17
- **读取长短信** → `AT+QCMGR` · AT Manual V2.2 §9.18

#### 10 分组域命令

- **PS 域附着/去附着** → `AT+CGATT` · AT Manual V2.2 §10.1
- **定义 PDP 上下文** → `AT+CGDCONT` · AT Manual V2.2 §10.2
- **请求 QoS 配置** → `AT+CGQREQ` · AT Manual V2.2 §10.3
- **最低可接受 QoS 配置** → `AT+CGQMIN` · AT Manual V2.2 §10.4
- **请求 UMTS QoS 配置** → `AT+CGEQREQ` · AT Manual V2.2 §10.5
- **最低可接受 UMTS QoS 配置** → `AT+CGEQMIN` · AT Manual V2.2 §10.6
- **激活/去激活 PDP 上下文** → `AT+CGACT` · AT Manual V2.2 §10.7
- **进入数据状态** → `AT+CGDATA` · AT Manual V2.2 §10.8
- **显示 PDP 地址** → `AT+CGPADDR` · AT Manual V2.2 §10.9
- **GPRS 移动台类别** → `AT+CGCLASS` · AT Manual V2.2 §10.10
- **查询网络注册状态** → `AT+CGREG` · AT Manual V2.2 §10.11
- **分组域事件上报** → `AT+CGEREP` · AT Manual V2.2 §10.12
- **选择短信发送承载域** → `AT+CGSMS` · AT Manual V2.2 §10.13
- **查 EPS/LTE 注册** → `AT+CEREG` · AT Manual V2.2 §10.14
- **流量计数器** → `AT+QGDCNT` · AT Manual V2.2 §10.15
- **自动保存流量计数** → `AT+QAUGDCNT` · AT Manual V2.2 §10.16
- **启动/停止 RmNet 拨号** → `AT$QCRMCALL` · AT Manual V2.2 §10.17
- **查询 RmNet 设备状态** → `AT+QNETDEVSTATUS` · AT Manual V2.2 §10.18
- **读取 PDP 上下文动态参数** → `AT+CGCONTRDP` · AT Manual V2.2 §10.19

#### 11 补充业务命令

- **呼叫转移控制** → `AT+CCFC` · AT Manual V2.2 §11.1
- **呼叫等待控制** → `AT+CCWA` · AT Manual V2.2 §11.2
- **呼叫相关补充业务** → `AT+CHLD` · AT Manual V2.2 §11.3
- **主叫号码显示** → `AT+CLIP` · AT Manual V2.2 §11.4
- **主叫号码显示限制** → `AT+CLIR` · AT Manual V2.2 §11.5
- **被叫号码显示** → `AT+COLP` · AT Manual V2.2 §11.6
- **补充业务通知** → `AT+CSSN` · AT Manual V2.2 §11.7
- **非结构化补充业务数据（USSD）** → `AT+CUSD` · AT Manual V2.2 §11.8

#### 12 音频命令

- **扬声器音量设置** → `AT+CLVL` · AT Manual V2.2 §12.1
- **静音控制** → `AT+CMUT` · AT Manual V2.2 §12.2
- **启用/关闭音频环回测试** → `AT+QAUDLOOP` · AT Manual V2.2 §12.3
- **DTMF 与音调生成** → `AT+VTS` · AT Manual V2.2 §12.4
- **设置音调时长** → `AT+VTD` · AT Manual V2.2 §12.5
- **设置音频模式** → `AT+QAUDMOD` · AT Manual V2.2 §12.6
- **数字音频接口配置** → `AT+QDAI` · AT Manual V2.2 §12.7
- **设置回声消除参数** → `AT+QEEC` · AT Manual V2.2 §12.8
- **设置当前模式侧音增益** → `AT+QSIDET` · AT Manual V2.2 §12.9
- **设置麦克风上行增益** → `AT+QMIC` · AT Manual V2.2 §12.10
- **设置下行接收增益** → `AT+QRXGAIN` · AT Manual V2.2 §12.11
- **通过 IIC 读写 Codec** → `AT+QIIC` · AT Manual V2.2 §12.12
- **启用/禁用 DTMF Detection** → `AT+QTONEDET` · AT Manual V2.2 §12.13
- **播放本地 DTMF** → `AT+QLDTMF` · AT Manual V2.2 §12.14
- **向对端播放/发送 DTMF** → `AT+QWDTMF` · AT Manual V2.2 §12.15
- **播放本地自定义音调** → `AT+QLTONE` · AT Manual V2.2 §12.16
- **录制媒体文件** → `AT+QAUDRD` · AT Manual V2.2 §12.17
- **播放 WAV 文件** → `AT+QPSND` · AT Manual V2.2 §12.18
- **文本转语音播放（TTS）** → `AT+QTTS` · AT Manual V2.2 §12.19
- **设置 TTS** → `AT+QTTSETUP` · AT Manual V2.2 §12.20
- **向对端播放文本语音** → `AT+QWTTS` · AT Manual V2.2 §12.21
- **查询与设置音频调试参数** — `AT+QAUDCFG` · AT Manual V2.2 §12.22
  - 查询与设置音频调试参数 → `AT+QAUDCFG`
  - 设置 Downlink Gain Levelfor Codec ALC5616 → `AT+QAUDCFG="alc5616/dlgain"`
  - 设置 the Uplink Gain Levelfor Codec ALC5616 → `AT+QAUDCFG="alc5616/ulgain"`
  - 设置 the Tone Volume → `AT+QAUDCFG="tonevolume"`
  - 启用/禁用 the Power Reset → `AT+QAUDCFG="alc5616/pwrctr"`
  - 设置 Downlink Gain Levelfor Codec NAU8814 → `AT+QAUDCFG="nau8814/dlgain"`
  - 设置 the Analog Outputfor Codec NAU8814 → `AT+QAUDCFG="nau8814/aoutput"`
  - 设置 Uplink ENC Gains → `AT+QAUDCFG="encgain"`
  - 设置 VoLTE DTMF 音时长与音量 → `AT+QAUDCFG="voltedtmfcfg"`
  - 设置 Downlink DEC Gains → `AT+QAUDCFG="decgain"`
  - 启用/禁用 Noise Suppression → `AT+QAUDCFG="fns"`
  - 设置 Register Valueof Codec NAU8810 → `AT+QAUDCFG="nau8810/config"`
  - 设置 UAC Sampling Rate → `AT+QAUDCFG="uac_fs"`
  - 启用/禁用 UAC Music → `AT+QAUDCFG="uac_music"`
- **播放媒体文件** → `AT+QAUDPLAY` · AT Manual V2.2 §12.23
- **设置音频播放增益** → `AT+QAUDPLAYGAIN` · AT Manual V2.2 §12.24
- **设置音频录制增益** → `AT+QAUDRDGAIN` · AT Manual V2.2 §12.25
- **写入 ACDB File** → `AT+QACDBLOAD` · AT Manual V2.2 §12.26
- **读取 ACDB File** → `AT+QACDBREAD` · AT Manual V2.2 §12.27
- **删除 ACDB File** → `AT+QACDBDEL` · AT Manual V2.2 §12.28

#### 13 硬件相关命令

- **关机** `[危险]` → `AT+QPOWD` · AT Manual V2.2 §13.1
- **时钟（读写时间）** → `AT+CCLK` · AT Manual V2.2 §13.2
- **电池电量** → `AT+CBC` · AT Manual V2.2 §13.3
- **读取 ADC Value** → `AT+QADC` · AT Manual V2.2 §13.4
- **启用/关闭低功耗（休眠）模式** → `AT+QSCLK` · AT Manual V2.2 §13.5

### QCFG V1.6

#### 2 测试命令

- **扩展配置设置** → `AT+QCFG` · QCFG V1.6 §2.1

#### 3 通用配置

- **设置 AP_Ready 行为** → `AT+QCFG="apready"` · QCFG V1.6 §3.1
- **设置 SLEEP_IND 引脚输出电平** → `AT+QCFG="sleepind/level"` · QCFG V1.6 §3.2
- **设置来电 RING URC 的 RI 行为** → `AT+QCFG="urc/ri/ring"` · QCFG V1.6 §3.4
- **设置来短信 URC 的 RI 行为** → `AT+QCFG="urc/ri/smsincoming"` · QCFG V1.6 §3.5
- **设置其他 URC 的 RI 行为** → `AT+QCFG="urc/ri/other"` · QCFG V1.6 §3.6
- **RI 信号输出载体** → `AT+QCFG="risignaltype"` · QCFG V1.6 §3.7
- **延迟 URC 上报输出** → `AT+QCFG="urc/delay"` · QCFG V1.6 §3.8
- **启用/禁用 URC Cache** → `AT+QCFG="urc/cache"` · QCFG V1.6 §3.9
- **设置开机 URC 输出** → `AT+QCFG="urc/poweron"` · QCFG V1.6 §3.10
- **设置 LTE/WCDMA 主分集接收** → `AT+QCFG="divctl"` · QCFG V1.6 §3.11
- **启用/关闭 Linux 服务** → `AT+QCFG="bootup"` · QCFG V1.6 §3.12
- **设置 RI 对应的 UART 引脚** → `AT+QCFG="urc/ri/pin"` · QCFG V1.6 §3.14
- **配置 Main UART** → `AT+QCFG="icf"` · QCFG V1.6 §3.15
- **配置 URC Delay** → `AT+QCFG="urcdelay"` · QCFG V1.6 §3.16
- **启用/关闭快速关机** → `AT+QCFG="fast/poweroff"` · QCFG V1.6 §3.17
- **设置数据缓存模式** → `AT+QCFG="sleep/datactrl"` · QCFG V1.6 §3.18
- **设置 RF 调谐器与频段映射** → `AT+QCFG="rf/tuner_cfg"` · QCFG V1.6 §3.19
- **保存/丢弃彩信** → `AT+QCFG="mms_rec_control"` · QCFG V1.6 §3.20

#### 4 音频配置

- **启用来电铃声** → `AT+QCFG="tone/incoming"` · QCFG V1.6 §4.1
- **配置 PCM_CLK** → `AT+QCFG="pcmclk"` · QCFG V1.6 §4.2
- **设置 ALC5616 Codec 的 PSM** → `AT+QCFG="codec/powsave"` · QCFG V1.6 §4.3

#### 5 网络配置

- **设置 GPRS 附着模式** → `AT+QCFG="gprsattach"` · QCFG V1.6 §5.1
- **设置网络搜索模式** → `AT+QCFG="nwscanmode"` · QCFG V1.6 §5.2
- **设置业务域** → `AT+QCFG="servicedomain"` · QCFG V1.6 §5.3
- **配置 Band** → `AT+QCFG="band"` · QCFG V1.6 §5.4
- **设置 RRC 版本** → `AT+QCFG="rrc"` · QCFG V1.6 §5.5
- **设置 MSC 版本** → `AT+QCFG="msc"` · QCFG V1.6 §5.6
- **设置 UE SGSN 版本** → `AT+QCFG="sgsn"` · QCFG V1.6 §5.7
- **配置 HSDPA Category** → `AT+QCFG="hsdpacat"` · QCFG V1.6 §5.8
- **配置 HSUPA Category** → `AT+QCFG="hsupacat"` · QCFG V1.6 §5.9
- **允许相同 APN 建立多 PDN** → `AT+QCFG="pdp/duplicatechk"` · QCFG V1.6 §5.10
- **禁用 LTE 回退** → `AT+QCFG="disable_backoff_lte"` · QCFG V1.6 §5.11
- **通过 W_DISABLE# 引脚进入/退出飞行模式** → `AT+QCFG="airplanecontrol"` · QCFG V1.6 §5.12
- **设置附着请求中的 EPC 能力值** → `AT+QCFG="epcflag"` · QCFG V1.6 §5.13
- **设置 LTE 频段搜索优先级** → `AT+QCFG="lte/bandprior"` · QCFG V1.6 §5.14
- **将当前 PLMN 加入 FPLMN** → `AT+QCFG="plmn/addinfbdn"` · QCFG V1.6 §5.15
- **启用/关闭 AT+COPS=1 下的模式切换** → `AT+QCFG="cops_no_mode_change"` · QCFG V1.6 §5.16
- **设置 HPLMN 搜索间隔** → `AT+QCFG="hplmn/search_timer"` · QCFG V1.6 §5.17
- **获取 LTE-TDD 配置** → `AT+QCFG="tdd/config"` · QCFG V1.6 §5.18
- **设置拒绝原因上报** → `AT+QCFG="urc_cause_support"` · QCFG V1.6 §5.19
- **过滤 DHCP 报文** → `AT+QCFG="dhcppktfltr"` · QCFG V1.6 §5.20
- **设置失网搜索模式** → `AT+QCFG="oostimer"` · QCFG V1.6 §5.21
- **设置 APN 阻止模式** → `AT+QCFG="apn/blocked"` · QCFG V1.6 §5.22
- **设置重定向模式** → `AT+QCFG="redir/3gtolte"` · QCFG V1.6 §5.23
- **设置 RSSI 变化的增量阈值** → `AT+QCFG="rssi"` · QCFG V1.6 §5.24
- **设置漫游业务** → `AT+QCFG="roamservice"` · QCFG V1.6 §5.25
- **动态设置 RRC 连接** → `AT+QCFG="fast_dormancy"` · QCFG V1.6 §5.26
- **设置飞行模式** → `AT+QCFG="airplane"` · QCFG V1.6 §5.27
- **设置 RRC 连接控制功能** → `AT+QCFG="rrc/control"` · QCFG V1.6 §5.28
- **设置网络搜索模式** → `AT+QCFG="nwscanmodeex"` · QCFG V1.6 §5.29
- **设置网关地址生成规则** → `AT+QCFG="iprulectl"` · QCFG V1.6 §5.31
- **设置网络搜索时禁用 RPLMN/RPLMNAct** → `AT+QCFG="disrplmn"` · QCFG V1.6 §5.32
- **设置 LTE 优先频点** → `AT+QCFG="lte/preferfre"` · QCFG V1.6 §5.33
- **启用/关闭 AT+COPS 配置** → `AT+QCFG="cops_control"` · QCFG V1.6 §5.34
- **启用/关闭自定义子网掩码** → `AT+QCFG="netmaskset"` · QCFG V1.6 §5.36
- **设置是否丢弃 Ping 报文** → `AT+QCFG="pingdiscard"` · QCFG V1.6 §5.37
- **设置 RI 脉冲定时器** → `AT+QCFG="urc/ri/restart"` · QCFG V1.6 §5.38
- **设置 Ping 检测功能** → `AT+QCFG="ping/ri"` · QCFG V1.6 §5.39
- **设置 PDP 上下文默认 DNS** → `AT+QCFG="defaultdns"` · QCFG V1.6 §5.40
- **设置唤醒机制** → `AT+QCFG="lpm/dataind"` · QCFG V1.6 §5.41
- **设置漫游状态相关功能** → `AT+QCFG="roamserviceex"` · QCFG V1.6 §5.42
- **设置 RAT 搜索顺序** → `AT+QCFG="nwscanseq"` · QCFG V1.6 §5.43

#### 6 PS 配置

- **设置 NTP 最大重传次数与间隔** → `AT+QCFG="ntp"` · QCFG V1.6 §6.1
- **设置 TCP 发送模式** → `AT+QCFG="TCP/SendMode"` · QCFG V1.6 §6.2
- **设置 TCP 窗口可用大小** → `AT+QCFG="tcp/windowsize"` · QCFG V1.6 §6.3

#### 7 CS / IMS 配置

- **设置 AMR 编解码** → `AT+QCFG="amrcodec"` · QCFG V1.6 §7.1
- **设置 GSM EFR/HR/FR 编解码** → `AT+QCFG="frhrcodec"` · QCFG V1.6 §7.2
- **设置 BIP 过程中的 PDP 认证类型** → `AT+QCFG="bip/auth"` · QCFG V1.6 §7.3
- **列出短信 Map** → `AT+QCFG="SMS/ListMsgMap"` · QCFG V1.6 §7.4
- **启用/禁用 IMS/UT Function** → `AT+QCFG="ims/ut"` · QCFG V1.6 §7.5
- **IMS/VoLTE 配置** — `AT+QCFG="ims"` · QCFG V1.6 §7.6
  - 强制开启 IMS/VoLTE 能力 → `AT+QCFG="ims",1`
  - 恢复默认 IMS（跟随 MBN） → `AT+QCFG="ims",0`
  - 强制关闭 IMS → `AT+QCFG="ims",2`
  - 查询 IMS/VoLTE 配置 → `AT+QCFG="ims"`
- **设置 LTE 模式下短信格式** → `AT+QCFG="ltesms/format"` · QCFG V1.6 §7.7
- **启用/禁用 VoLTE** `[危险]` → `AT+QCFG="volte_disable"` · QCFG V1.6 §7.8
- **设置 OMADM 短信解析模式** → `AT+QCFG="sms/omadm"` · QCFG V1.6 §7.9
- **配置 IMS 注册 IP 类型** → `AT+QCFG="imsreg/iptype"` · QCFG V1.6 §7.10
- **设置 (U)SIM 卡热插拔** → `AT+QCFG="sim/recovery"` · QCFG V1.6 §7.11
- **启用/禁用 Re -attach 查询** → `AT+QCFG="siminvalirecovery"` · QCFG V1.6 §7.12
- **启用/关闭漫游模式下语音通话** → `AT+QCFG="roaming/voicecall"` · QCFG V1.6 §7.13
- **设置忙音播放** → `AT+QCFG="voice_busytone"` · QCFG V1.6 §7.14

#### 8 PPP 配置

- **启用/关闭 PPP TERM 帧发送** → `AT+QCFG="ppp/termframe"` · QCFG V1.6 §8.1

#### 9 USB 配置

- **USB 网卡模式** — `AT+QCFG="usbnet"` · QCFG V1.6 §9.1
  - 网卡改为 QMI/RmNet → `AT+QCFG="usbnet",0`
  - 网卡改为 ECM → `AT+QCFG="usbnet",1`
  - 网卡改为 MBIM → `AT+QCFG="usbnet",2`
  - 网卡改为 RNIDS → `AT+QCFG="usbnet",3`
  - 查询网卡模式 → `AT+QCFG="usbnet"`
- **设置 VID、PID 及端口配置** → `AT+QCFG="usbcfg"` · QCFG V1.6 §9.2
- **设置 USB 设备加载** → `AT+QCFG="usbee"` · QCFG V1.6 §9.3
- **获取 USB 模式** → `AT+QCFG="usbmode"` · QCFG V1.6 §9.4
- **设置 SPI 或 UART 驱动** → `AT+QCFG="spi/set"` · QCFG V1.6 §9.5
- **启用 USB 枚举失败优化** → `AT+QCFG="usbenum/seoctl"` · QCFG V1.6 §9.6

#### 10 CDMA 配置

- **设置 CDMA 下 PPP 认证优化** → `AT+QCFG="cdma/pppauth"` · QCFG V1.6 §10.1
- **配置 CDMA Mode** → `AT+QCFG="ehrpd"` · QCFG V1.6 §10.2
- **设置 CDMA 短信 PDU 的 CMT 格式** → `AT+QCFG="cdmasms/cmtformat"` · QCFG V1.6 §10.3

#### 11 短信配置

- **设置短信 URC 输出端口** → `AT+QCFG="urcport/sms"` · QCFG V1.6 §11.1
- **启用/关闭短信下发或提交** → `AT+QCFG="sms_control"` · QCFG V1.6 §11.3

### QSIMCFG V1.0

#### 2 QSIMCFG 命令详解

- **查询/设置 SIM 卡配置** `[危险]` — `AT+QSIMCFG` · QSIMCFG V1.0 §2.3.1
  - 查询/设置 SIM 卡配置 → `AT+QSIMCFG`
  - 启用/禁用物理 (U)SIM 卡 `[危险]` → `AT+QSIMCFG="disable_physim"`
  - 查 SIM 应用类型 → `AT+QSIMCFG="app_type"`
  - 查 ATR → `AT+QSIMCFG="atr"`
  - 查 EID → `AT+QSIMCFG="eid"`
  - 查卡槽状态 → `AT+QSIMCFG="slot_status"`
  - 查 eSIM SGP 版本 → `AT+QSIMCFG="esim_svn"`

## 危险命令

| 用途 | 命令 | 说明 | 出处 |
|------|------|------|------|
| 启用/禁用（U）SIM 卡 | `AT+QSIMCFG="disable_physim"` | 会禁用实体卡，勿随意执行。 | QSIMCFG V1.0 |
| 发送短信 | `AT+CMGS` | 误发风险。 | AT Manual V2.2 §9.8 |
| 启用/禁用 VoLTE（另一套开关） | `AT+QCFG="volte_disable"` | 与 AT+QCFG="ims" 不同，易混淆。 | QCFG V1.6 §7.8 |
| 恢复出厂 AT 设置 | `AT&F` | 会重置 AT 配置，请确认。 | AT Manual V2.2 §2.10 |
| 关机 | `AT+QPOWD` | 会关闭模组电源。 | AT Manual V2.2 §13 |
| 删除短信 | `AT+CMGD` | 会删除已存短信。 | AT Manual V2.2 §9.5 |
| 从存储发送短信 | `AT+CMSS` | 会实际发出短信。 | AT Manual V2.2 §9.11 |
| 发送长短信 | `AT+QCMGS` | 误发风险。 | AT Manual V2.2 §9.17 |
| 删除 MBN 文件 | `AT+QMBNCFG="Delete"` | 可能破坏运营商配置。 | AT Manual V2.2 §4.4.6 |
| 切换 SIM 卡槽 | `AT+QDSIM` | 会切换卡槽，可能掉网。 | AT Manual V2.2 §5.12 |
| 修改 IMEI | `AT+EGMR` | 会改写模组 IMEI，请确认号码正确。 | Quectel EGMR |

