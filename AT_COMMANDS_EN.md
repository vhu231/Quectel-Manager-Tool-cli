# Quectel AT Commands (English)

CLI script `quick-at.sh` (no dialog TUI). Language: menu / `--lang zh|en` / `QUICK_AT_LANG` (session only).
By default **no persistent user data**. Pass `--log` to keep logs:
- `./quick-at.sh --log` → `./quick-at.log` next to the script
- `./quick-at.sh --log /path/to/file.log` → custom path
AT responses append PDF notes. Chinese: [AT_COMMANDS_ZH.md](AT_COMMANDS_ZH.md).
Controls: number to select; `b`=back; `q`=quit. On modem page Enter=refresh.
Loading shows `...` animation; screen clears with a sticky header (immersive CLI).

## Manual sources

- `at`: AT Manual V2.2 — `Quectel_EC2xEG2xEG9xEM05_Series_AT_Commands_Manual_V2.2.pdf`
- `qcfg`: QCFG V1.6 — `Quectel_EC2xEG2xEG9xEM05_Series_QCFG_AT_Commands_Manual_V1.6.pdf`
- `qsimcfg`: QSIMCFG V1.0 — `Quectel_EC2xEG2xEG9xEM05系列_QSIMCFG_AT命令手册_V1.0.pdf`

## Official semantics (IMS / usbnet)

- `AT+QCFG="ims"`: `0` follow MBN; `1` force on; `2` force off; **reboot required**.
- `AT+QCFG="usbnet"`: `0` RmNet; `1` ECM; `2` MBIM; `3` RNIDS; **reboot required**.
- Prefer `ims` over `volte_disable` for daily use.

## Daily quick presets (grouped)

Pick a group, then an action (single-action groups run immediately).

### 1 IMS/VoLTE config — `AT+QCFG="ims"`

| Action | Command | Notes | Ref |
|--------|---------|-------|-----|
| Force enable IMS/VoLTE | `AT+QCFG="ims",1` | Force on; reboot required. | QCFG V1.6 §7.6 |
| Restore default IMS (follow MBN) | `AT+QCFG="ims",0` | MBN default; reboot required. | QCFG V1.6 §7.6 |
| Force disable IMS | `AT+QCFG="ims",2` | Force off (not 0); reboot required. | QCFG V1.6 §7.6 |
| Query IMS/VoLTE config | `AT+QCFG="ims"` | Returns ims_conf,volte_cap. | QCFG V1.6 §7.6 |

### 2 USB net mode — `AT+QCFG="usbnet"`

| Action | Command | Notes | Ref |
|--------|---------|-------|-----|
| Set USB net to QMI/RmNet | `AT+QCFG="usbnet",0` | 0=RmNet 1=ECM 2=MBIM 3=RNIDS; reboot. | QCFG V1.6 §9.1 |
| Set USB net to ECM | `AT+QCFG="usbnet",1` | Reboot required. | QCFG V1.6 §9.1 |
| Set USB net to MBIM | `AT+QCFG="usbnet",2` | Reboot required. | QCFG V1.6 §9.1 |
| Set USB net to RNIDS | `AT+QCFG="usbnet",3` | Reboot required. | QCFG V1.6 §9.1 |
| Query USB net mode | `AT+QCFG="usbnet"` | Read current <net> value. | QCFG V1.6 §9.1 |

### 3–4 Others

| ID | Purpose | Command | Notes | Ref |
|----|---------|---------|-------|-----|
| 3 | Reboot and apply config | `AT+CFUN=1,1` | Apply ims/usbnet settings. | AT Manual V2.2 |
| 4 | Write IMEI (EGMR) | `AT+EGMR=1,7,"<IMEI>"` | Prompts for IMEI; dangerous; reboot usually required. | Quectel EGMR |

## Browse AT catalog (group → action)

Path: Chapter (AT / QCFG / QSIMCFG merged) → **group** → **action**. Multi-action groups open a submenu; single-action runs immediately. Dangerous items marked `[DANGER]`.

### AT Manual V2.2

#### 2 General Commands

- **Set Command Echo Mode** → `ATE` · AT Manual V2.2 §2.x
- **Request Identification Information** → `ATI` · AT Manual V2.2 §2.x
- **Set to Default Configuration** → `ATZ` · AT Manual V2.2 §2.x
- **Request Manufacturer Identification** → `AT+GMI` · AT Manual V2.2 §2.2
- **Request Model Identification** → `AT+GMM` · AT Manual V2.2 §2.3
- **Request TA Firmware Revision Identification** → `AT+GMR` · AT Manual V2.2 §2.4
- **Request Manufacturer Identification** → `AT+CGMI` · AT Manual V2.2 §2.5
- **Request Model Identification** → `AT+CGMM` · AT Manual V2.2 §2.6
- **Request MT Firmware Revision Identification** → `AT+CGMR` · AT Manual V2.2 §2.7
- **Request International Mobile Equipment Identity (IMEI) and SN** → `AT+GSN` · AT Manual V2.2 §2.8
- **Request International Mobile Equipment Identity (IMEI)** → `AT+CGSN` · AT Manual V2.2 §2.9
- **Reset to Factory Defaults** `[DANGER]` → `AT&F` · AT Manual V2.2 §2.10
- **Display Current Configuration** → `AT&V` · AT Manual V2.2 §2.11
- **Store Settings to User Profile** → `AT&W` · AT Manual V2.2 §2.12
- **Module functionality (CFUN)** — `AT+CFUN` · AT Manual V2.2 §2.22
  - Query functionality → `AT+CFUN`
  - Minimum functionality → `AT+CFUN=0`
  - Full functionality → `AT+CFUN=1`
  - RF off (airplane-like) → `AT+CFUN=4`
  - Full functionality + reset → `AT+CFUN=1,1`
- **Report Mobile Equipment Error** → `AT+CMEE` · AT Manual V2.2 §2.23
- **Select TE Character Set** → `AT+CSCS` · AT Manual V2.2 §2.24
- **Configure URC Indication Option** → `AT+QURCCFG` · AT Manual V2.2 §2.25
- **Configureto Report Specified URC** → `AT+QAPRDYIND` · AT Manual V2.2 §2.26
- **Debug UART Configuration** → `AT+QDIAGPORT` · AT Manual V2.2 §2.27

#### 3 Serial Interface Control Commands

- **Set DCD Function Mode** → `AT&C` · AT Manual V2.2 §3.1
- **Set DTR Function Mode** → `AT&D` · AT Manual V2.2 §3.2
- **Set TE-TA Local Data Flow Control** → `AT+IFC` · AT Manual V2.2 §3.3
- **Set TE-TA Character Framing** → `AT+ICF` · AT Manual V2.2 §3.4
- **Set TE-TA Fixed Local Rate** → `AT+IPR` · AT Manual V2.2 §3.5
- **Restore RI Behavior to Inactive** → `AT+QRIR` · AT Manual V2.2 §3.6

#### 4 Status Control Commands

- **Mobile Equipment Activity Status** → `AT+CPAS` · AT Manual V2.2 §4.1
- **Extended Error Report** → `AT+CEER` · AT Manual V2.2 §4.2
- **URC Indication Configuration** → `AT+QINDCFG` · AT Manual V2.2 §4.3
- **MBN File Configuration** `[DANGER]` — `AT+QMBNCFG` · AT Manual V2.2 §4.4
  - MBN File Configuration → `AT+QMBNCFG`
  - Query Imported MBN File List → `AT+QMBNCFG="List"`
  - Select Imported MBN File → `AT+QMBNCFG="Select"`
  - Deactivate MBN File → `AT+QMBNCFG="Deactivate"`
  - Auto Select Whetherto Activate MBN File → `AT+QMBNCFG="AutoSel"`
  - Add MBN File → `AT+QMBNCFG="Add"`
  - Delete MBN File `[DANGER]` → `AT+QMBNCFG="Delete"`

#### 5 (U)SIM Related Commands

- **Request International Mobile Subscriber Identity (IMSI)** → `AT+CIMI` · AT Manual V2.2 §5.1
- **Facility Lock** → `AT+CLCK` · AT Manual V2.2 §5.2
- **Enter PIN** → `AT+CPIN` · AT Manual V2.2 §5.3
- **Change Password** → `AT+CPWD` · AT Manual V2.2 §5.4
- **Generic (U)SIM Access** → `AT+CSIM` · AT Manual V2.2 §5.5
- **Restricted (U)SIM Access** → `AT+CRSM` · AT Manual V2.2 §5.6
- **Show ICCID** → `AT+QCCID` · AT Manual V2.2 §5.7
- **Display PIN Remainder Counter** → `AT+QPINC` · AT Manual V2.2 §5.8
- **Query (U)SIM Card Initialization Status** → `AT+QINISTAT` · AT Manual V2.2 §5.9
- **(U)SIM Card Detection** → `AT+QSIMDET` · AT Manual V2.2 §5.10
- **(U)SIM Card Insertion Status Report** → `AT+QSIMSTAT` · AT Manual V2.2 §5.11
- **Switch (U)SIM Card Slot** `[DANGER]` → `AT+QDSIM` · AT Manual V2.2 §5.12
- **Fix (U)SIM Card Supply Voltage** → `AT+QSIMVOL` · AT Manual V2.2 §5.13
- **Open Logical Channel** → `AT+CCHO` · AT Manual V2.2 §5.14
- **UICC Logical Channel Access** → `AT+CGLA` · AT Manual V2.2 §5.15
- **Close Logical Channel** → `AT+CCHC` · AT Manual V2.2 §5.16

#### 6 Network Service Commands

- **Operator Selection** → `AT+COPS` · AT Manual V2.2 §6.1
- **Network Registration Status** → `AT+CREG` · AT Manual V2.2 §6.2
- **Signal Quality Report** → `AT+CSQ` · AT Manual V2.2 §6.3
- **Report Signal Quality** → `AT+QCSQ` · AT Manual V2.2 §6.4
- **Preferred Operator List** → `AT+CPOL` · AT Manual V2.2 §6.5
- **Read Operator Names** → `AT+COPN` · AT Manual V2.2 §6.6
- **Automatic Time Zone Update** → `AT+CTZU` · AT Manual V2.2 §6.7
- **Time Zone Reporting** → `AT+CTZR` · AT Manual V2.2 §6.8
- **Obtainthe Latest Time Synchronized Through Network** → `AT+QLTS` · AT Manual V2.2 §6.9
- **Query Network Information** → `AT+QNWINFO` · AT Manual V2.2 §6.10
- **Displaythe Nameof Registered Network** → `AT+QSPN` · AT Manual V2.2 §6.11
- **Query Network Informationof RATs** → `AT+QNETINFO` · AT Manual V2.2 §6.12
- **Network Locking (LTE)** → `AT+QNWLOCK="common/lte"` · AT Manual V2.2 §6.13
- **Manual Band Scan Configuration** — `AT+QOPSCFG` · AT Manual V2.2 §6.14
  - Manual Band Scan Configuration → `AT+QOPSCFG`
  - Configure Bandstobe Scannedin 2G/3G/4G → `AT+QOPSCFG="scancontrol"`
  - Enable/Disableto Display RSSIin LTE → `AT+QOPSCFG="displayrssi"`
  - Enable/Disableto Display Bandwidthin LTE → `AT+QOPSCFG="displaybw"`
  - Set Maximum Durationfor Manual Band Scan → `AT+QOPSCFG="guard_timer"`
- **Band Scan** → `AT+QOPS` · AT Manual V2.2 §6.15
- **FPLMN Configuration** → `AT+QFPLMNCFG` · AT Manual V2.2 §6.16
- **Engineering Mode** → `AT+QENG` · AT Manual V2.2 §6.17
- **Indicator Control** → `AT+CIND` · AT Manual V2.2 §6.18

#### 7 Call Related Commands

- **Voice Hangup Control** → `AT+CVHU` · AT Manual V2.2 §7.4
- **Hang Up Voice Call** → `AT+CHUP` · AT Manual V2.2 §7.5
- **Select Bearer Service Type** → `AT+CBST` · AT Manual V2.2 §7.14
- **Select Type of Address** → `AT+CSTA` · AT Manual V2.2 §7.15
- **List Current Calls** → `AT+CLCC` · AT Manual V2.2 §7.16
- **Service Reporting Control** → `AT+CR` · AT Manual V2.2 §7.17
- **Cellular Result Codes for Incoming Call Indication** → `AT+CRC` · AT Manual V2.2 §7.18
- **Radio Link Protocol Parameters** → `AT+CRLP` · AT Manual V2.2 §7.19
- **Configure Emergency Call Numbers** → `AT+QECCNUM` · AT Manual V2.2 §7.20
- **Hang Up Call with a Specific Release Cause** → `AT+QHUP` · AT Manual V2.2 §7.21
- **Hang Up a Call in the VoLTE Conference** → `AT+QCHLDIPMPTY` · AT Manual V2.2 §7.22

#### 8 Phonebook Commands

- **Subscriber Number** → `AT+CNUM` · AT Manual V2.2 §8.1
- **Find Phonebook Entries** → `AT+CPBF` · AT Manual V2.2 §8.2
- **Read Phonebook Entries** → `AT+CPBR` · AT Manual V2.2 §8.3
- **Select Phonebook Memory Storage** → `AT+CPBS` · AT Manual V2.2 §8.4
- **Write Phonebook Entry** → `AT+CPBW` · AT Manual V2.2 §8.5

#### 9 Short Message Service Commands

- **Select Message Service** → `AT+CSMS` · AT Manual V2.2 §9.1
- **Message Format** → `AT+CMGF` · AT Manual V2.2 §9.2
- **Service Center Address** → `AT+CSCA` · AT Manual V2.2 §9.3
- **Preferred Message Storage** → `AT+CPMS` · AT Manual V2.2 §9.4
- **Delete Message** `[DANGER]` → `AT+CMGD` · AT Manual V2.2 §9.5
- **List Message** → `AT+CMGL` · AT Manual V2.2 §9.6
- **Read Message** → `AT+CMGR` · AT Manual V2.2 §9.7
- **Send Message** `[DANGER]` → `AT+CMGS` · AT Manual V2.2 §9.8
- **More Messages to Send** → `AT+CMMS` · AT Manual V2.2 §9.9
- **Write Message to Memory** → `AT+CMGW` · AT Manual V2.2 §9.10
- **Send Message from Storage** `[DANGER]` → `AT+CMSS` · AT Manual V2.2 §9.11
- **New Message Acknowledgement** → `AT+CNMA` · AT Manual V2.2 §9.12
- **SMS Event Reporting Configuration** → `AT+CNMI` · AT Manual V2.2 §9.13
- **Select Cell Broadcast Message Types** → `AT+CSCB` · AT Manual V2.2 §9.14
- **Show SMS Text Mode Parameters** → `AT+CSDH` · AT Manual V2.2 §9.15
- **Set SMS Text Mode Parameters** → `AT+CSMP` · AT Manual V2.2 §9.16
- **Send Concatenated Messages** `[DANGER]` → `AT+QCMGS` · AT Manual V2.2 §9.17
- **Read Concatenated Messages** → `AT+QCMGR` · AT Manual V2.2 §9.18

#### 10 Packet Domain Commands

- **Attachmentor Detachmentof PS** → `AT+CGATT` · AT Manual V2.2 §10.1
- **Define PDP Context** → `AT+CGDCONT` · AT Manual V2.2 §10.2
- **Quality of Service Profile (Requested)** → `AT+CGQREQ` · AT Manual V2.2 §10.3
- **Quality of Service Profile (Minimum Acceptable)** → `AT+CGQMIN` · AT Manual V2.2 §10.4
- **UMTS Quality of Service Profile (Requested)** → `AT+CGEQREQ` · AT Manual V2.2 §10.5
- **UMTS Quality of Service Profile (Minimum Acceptable)** → `AT+CGEQMIN` · AT Manual V2.2 §10.6
- **Activate or Deactivate PDP Context** → `AT+CGACT` · AT Manual V2.2 §10.7
- **Enter Data State** → `AT+CGDATA` · AT Manual V2.2 §10.8
- **Show PDP Address** → `AT+CGPADDR` · AT Manual V2.2 §10.9
- **GPRS Mobile Station Class** → `AT+CGCLASS` · AT Manual V2.2 §10.10
- **Network Registration Status** → `AT+CGREG` · AT Manual V2.2 §10.11
- **Packet Domain Event Reporting** → `AT+CGEREP` · AT Manual V2.2 §10.12
- **Select Service for MO SMS Messages** → `AT+CGSMS` · AT Manual V2.2 §10.13
- **EPS Network Registration Status** → `AT+CEREG` · AT Manual V2.2 §10.14
- **Packet Data Counter** → `AT+QGDCNT` · AT Manual V2.2 §10.15
- **Auto Save Packet Data Counter** → `AT+QAUGDCNT` · AT Manual V2.2 §10.16
- **Start or Stop an RmNet Call** → `AT$QCRMCALL` · AT Manual V2.2 §10.17
- **Query RmNet Device Status** → `AT+QNETDEVSTATUS` · AT Manual V2.2 §10.18
- **Read PDP Context Dynamic Parameters** → `AT+CGCONTRDP` · AT Manual V2.2 §10.19

#### 11 Supplementary Service Commands

- **Call Forwarding Number and Conditions Control** → `AT+CCFC` · AT Manual V2.2 §11.1
- **Call Waiting Control** → `AT+CCWA` · AT Manual V2.2 §11.2
- **Call Related Supplementary Services** → `AT+CHLD` · AT Manual V2.2 §11.3
- **Calling Line Identification Presentation** → `AT+CLIP` · AT Manual V2.2 §11.4
- **Calling Line Identification Restriction** → `AT+CLIR` · AT Manual V2.2 §11.5
- **Connected Line Identification Presentation** → `AT+COLP` · AT Manual V2.2 §11.6
- **Supplementary Service Notifications** → `AT+CSSN` · AT Manual V2.2 §11.7
- **Unstructured Supplementary Service Data** → `AT+CUSD` · AT Manual V2.2 §11.8

#### 12 Audio Commands

- **Loudspeaker Volume Level** → `AT+CLVL` · AT Manual V2.2 §12.1
- **Mute Control** → `AT+CMUT` · AT Manual V2.2 §12.2
- **Audio Loop Test** → `AT+QAUDLOOP` · AT Manual V2.2 §12.3
- **DTMF and Tone Generation** → `AT+VTS` · AT Manual V2.2 §12.4
- **Tone Duration** → `AT+VTD` · AT Manual V2.2 §12.5
- **Set Audio Mode** → `AT+QAUDMOD` · AT Manual V2.2 §12.6
- **Digital Audio Interface Configuration** → `AT+QDAI` · AT Manual V2.2 §12.7
- **Set Echo Cancellation Parameters** → `AT+QEEC` · AT Manual V2.2 §12.8
- **Set Side Tone Gain in Current Mode** → `AT+QSIDET` · AT Manual V2.2 §12.9
- **Set Uplink Gains of Microphone** → `AT+QMIC` · AT Manual V2.2 §12.10
- **Set Downlink Gains of RX** → `AT+QRXGAIN` · AT Manual V2.2 §12.11
- **Read and Write Codec via IIC** → `AT+QIIC` · AT Manual V2.2 §12.12
- **Enable/Disable DTMF Detection** → `AT+QTONEDET` · AT Manual V2.2 §12.13
- **Play Local DTMF** → `AT+QLDTMF` · AT Manual V2.2 §12.14
- **Play or Send DTMF Files to Far End** → `AT+QWDTMF` · AT Manual V2.2 §12.15
- **Play a Local Customized Tone** → `AT+QLTONE` · AT Manual V2.2 §12.16
- **Record Media File** → `AT+QAUDRD` · AT Manual V2.2 §12.17
- **Play WAV File** → `AT+QPSND` · AT Manual V2.2 §12.18
- **Play Text (TTS)** → `AT+QTTS` · AT Manual V2.2 §12.19
- **Set TTS** → `AT+QTTSETUP` · AT Manual V2.2 §12.20
- **Play Text or Send Text to Far End** → `AT+QWTTS` · AT Manual V2.2 §12.21
- **Query and Configure Audio Tuning Process** — `AT+QAUDCFG` · AT Manual V2.2 §12.22
  - Query and Configure Audio Tuning Process → `AT+QAUDCFG`
  - Set Downlink Gain Levelfor Codec ALC5616 → `AT+QAUDCFG="alc5616/dlgain"`
  - Setthe Uplink Gain Levelfor Codec ALC5616 → `AT+QAUDCFG="alc5616/ulgain"`
  - Setthe Tone Volume → `AT+QAUDCFG="tonevolume"`
  - Enable/Disablethe Power Reset → `AT+QAUDCFG="alc5616/pwrctr"`
  - Set Downlink Gain Levelfor Codec NAU8814 → `AT+QAUDCFG="nau8814/dlgain"`
  - Setthe Analog Outputfor Codec NAU8814 → `AT+QAUDCFG="nau8814/aoutput"`
  - Set Uplink ENC Gains → `AT+QAUDCFG="encgain"`
  - Set Durationand Volumeof VoLTE DTMF Tone → `AT+QAUDCFG="voltedtmfcfg"`
  - Set Downlink DEC Gains → `AT+QAUDCFG="decgain"`
  - Enable/Disable Noise Suppression → `AT+QAUDCFG="fns"`
  - Set Register Valueof Codec NAU8810 → `AT+QAUDCFG="nau8810/config"`
  - Set UAC Sampling Rate → `AT+QAUDCFG="uac_fs"`
  - Enable/Disable UAC Music → `AT+QAUDCFG="uac_music"`
- **Play Media File** → `AT+QAUDPLAY` · AT Manual V2.2 §12.23
- **Set Audio Playing Gain** → `AT+QAUDPLAYGAIN` · AT Manual V2.2 §12.24
- **Set Audio Recording Gain** → `AT+QAUDRDGAIN` · AT Manual V2.2 §12.25
- **Write ACDB File** → `AT+QACDBLOAD` · AT Manual V2.2 §12.26
- **Read ACDB File** → `AT+QACDBREAD` · AT Manual V2.2 §12.27
- **Delete ACDB File** → `AT+QACDBDEL` · AT Manual V2.2 §12.28

#### 13 Hardware Related Commands

- **Power Off** `[DANGER]` → `AT+QPOWD` · AT Manual V2.2 §13.1
- **Clock** → `AT+CCLK` · AT Manual V2.2 §13.2
- **Battery Charge** → `AT+CBC` · AT Manual V2.2 §13.3
- **Read ADC Value** → `AT+QADC` · AT Manual V2.2 §13.4
- **Enable/Disable Low Power Mode** → `AT+QSCLK` · AT Manual V2.2 §13.5

### QCFG V1.6

#### 2 Test Command

- **Extended Configuration Settings** → `AT+QCFG` · QCFG V1.6 §2.1

#### 3 General Commands

- **Configure AP_Ready Behavior** → `AT+QCFG="apready"` · QCFG V1.6 §3.1
- **Set SLEEP_IND Pin Output Level** → `AT+QCFG="sleepind/level"` · QCFG V1.6 §3.2
- **Set RI Behavior for RING URC** → `AT+QCFG="urc/ri/ring"` · QCFG V1.6 §3.4
- **Set RI Behavior for Incoming SMS URC** → `AT+QCFG="urc/ri/smsincoming"` · QCFG V1.6 §3.5
- **Set RI Behavior for Other URCs** → `AT+QCFG="urc/ri/other"` · QCFG V1.6 §3.6
- **RI Signal Output Carrier** → `AT+QCFG="risignaltype"` · QCFG V1.6 §3.7
- **Delay URC Indication Output** → `AT+QCFG="urc/delay"` · QCFG V1.6 §3.8
- **Enable/Disable URC Cache** → `AT+QCFG="urc/cache"` · QCFG V1.6 §3.9
- **Set Power-on URC Output** → `AT+QCFG="urc/poweron"` · QCFG V1.6 §3.10
- **Set Primary and Rx-diversity under LTE/WCDMA** → `AT+QCFG="divctl"` · QCFG V1.6 §3.11
- **Enable/Disable Services in Linux** → `AT+QCFG="bootup"` · QCFG V1.6 §3.12
- **Set UART Pin Corresponding to RI** → `AT+QCFG="urc/ri/pin"` · QCFG V1.6 §3.14
- **Configure Main UART** → `AT+QCFG="icf"` · QCFG V1.6 §3.15
- **Configure URC Delay** → `AT+QCFG="urcdelay"` · QCFG V1.6 §3.16
- **Enable/Disable Fast Power-Off** → `AT+QCFG="fast/poweroff"` · QCFG V1.6 §3.17
- **Set Data Cache Mode** → `AT+QCFG="sleep/datactrl"` · QCFG V1.6 §3.18
- **Set Mapping between RF Tuner and RF Bands** → `AT+QCFG="rf/tuner_cfg"` · QCFG V1.6 §3.19
- **Save/Discard MMS** → `AT+QCFG="mms_rec_control"` · QCFG V1.6 §3.20

#### 4 Audio Commands

- **Enable Ring Tone** → `AT+QCFG="tone/incoming"` · QCFG V1.6 §4.1
- **Configure PCM_CLK** → `AT+QCFG="pcmclk"` · QCFG V1.6 §4.2
- **Set PSM for ALC5616 Codec** → `AT+QCFG="codec/powsave"` · QCFG V1.6 §4.3

#### 5 Network Commands

- **Set GPRS Attach Mode** → `AT+QCFG="gprsattach"` · QCFG V1.6 §5.1
- **Set Network Search Mode** → `AT+QCFG="nwscanmode"` · QCFG V1.6 §5.2
- **Set Service Domain** → `AT+QCFG="servicedomain"` · QCFG V1.6 §5.3
- **Configure Band** → `AT+QCFG="band"` · QCFG V1.6 §5.4
- **Set RRC Release Version** → `AT+QCFG="rrc"` · QCFG V1.6 §5.5
- **Set MSC Release Version** → `AT+QCFG="msc"` · QCFG V1.6 §5.6
- **Set UE SGSN Release Version** → `AT+QCFG="sgsn"` · QCFG V1.6 §5.7
- **Configure HSDPA Category** → `AT+QCFG="hsdpacat"` · QCFG V1.6 §5.8
- **Configure HSUPA Category** → `AT+QCFG="hsupacat"` · QCFG V1.6 §5.9
- **Establish Multi-PDN with Same APN** → `AT+QCFG="pdp/duplicatechk"` · QCFG V1.6 §5.10
- **Disable LTE Backoff** → `AT+QCFG="disable_backoff_lte"` · QCFG V1.6 §5.11
- **Enter/Exit Airplane Mode via W_DISABLE# Pin** → `AT+QCFG="airplanecontrol"` · QCFG V1.6 §5.12
- **Set EPC Capability Value in Attach Request** → `AT+QCFG="epcflag"` · QCFG V1.6 §5.13
- **Set LTE Band Search Priority** → `AT+QCFG="lte/bandprior"` · QCFG V1.6 §5.14
- **Add Current PLMN to FPLMN** → `AT+QCFG="plmn/addinfbdn"` · QCFG V1.6 §5.15
- **Enable/Disable Switch under AT+COPS=1** → `AT+QCFG="cops_no_mode_change"` · QCFG V1.6 §5.16
- **Set HPLMN Search Interval** → `AT+QCFG="hplmn/search_timer"` · QCFG V1.6 §5.17
- **Get LTE-TDD Configuration** → `AT+QCFG="tdd/config"` · QCFG V1.6 §5.18
- **Set Rejection Cause** → `AT+QCFG="urc_cause_support"` · QCFG V1.6 §5.19
- **Filter DHCP Packets** → `AT+QCFG="dhcppktfltr"` · QCFG V1.6 §5.20
- **Set Mode for OOS Network Searching** → `AT+QCFG="oostimer"` · QCFG V1.6 §5.21
- **Set APN Block Mode** → `AT+QCFG="apn/blocked"` · QCFG V1.6 §5.22
- **Set Redirection Mode** → `AT+QCFG="redir/3gtolte"` · QCFG V1.6 §5.23
- **Set Delta Threshold of RSSI Change** → `AT+QCFG="rssi"` · QCFG V1.6 §5.24
- **Set Roaming Service** → `AT+QCFG="roamservice"` · QCFG V1.6 §5.25
- **Dynamically Set RRC Connection** → `AT+QCFG="fast_dormancy"` · QCFG V1.6 §5.26
- **Set Airplane Mode** → `AT+QCFG="airplane"` · QCFG V1.6 §5.27
- **Set RRC Connection Control Feature** → `AT+QCFG="rrc/control"` · QCFG V1.6 §5.28
- **Set Network Searching Mode** → `AT+QCFG="nwscanmodeex"` · QCFG V1.6 §5.29
- **Set Gateway Address Generation Rule** → `AT+QCFG="iprulectl"` · QCFG V1.6 §5.31
- **Disable RPLMN and RPLMNAct for Network Searching** → `AT+QCFG="disrplmn"` · QCFG V1.6 §5.32
- **Set Preferred Frequency** → `AT+QCFG="lte/preferfre"` · QCFG V1.6 §5.33
- **Enable/Disable AT+COPS Configurations** → `AT+QCFG="cops_control"` · QCFG V1.6 §5.34
- **Enable/Disable Customized Netmask** → `AT+QCFG="netmaskset"` · QCFG V1.6 §5.36
- **Set Whether to Discard Ping Packet** → `AT+QCFG="pingdiscard"` · QCFG V1.6 §5.37
- **Set RI Pulse Timer** → `AT+QCFG="urc/ri/restart"` · QCFG V1.6 §5.38
- **Set Ping Detection Function** → `AT+QCFG="ping/ri"` · QCFG V1.6 §5.39
- **Set Default DNS for PDP Context** → `AT+QCFG="defaultdns"` · QCFG V1.6 §5.40
- **Set Wake-up Mechanism** → `AT+QCFG="lpm/dataind"` · QCFG V1.6 §5.41
- **Set Relevant Functions in Roaming State** → `AT+QCFG="roamserviceex"` · QCFG V1.6 §5.42
- **Set RATs Searching Sequence** → `AT+QCFG="nwscanseq"` · QCFG V1.6 §5.43

#### 6 PS Commands

- **Set NTP Max Retransmission Count and Interval** → `AT+QCFG="ntp"` · QCFG V1.6 §6.1
- **Set TCP Sending Mode** → `AT+QCFG="TCP/SendMode"` · QCFG V1.6 §6.2
- **Set TCP Window Available Size** → `AT+QCFG="tcp/windowsize"` · QCFG V1.6 §6.3

#### 7 CS Commands

- **Set AMR Codec** → `AT+QCFG="amrcodec"` · QCFG V1.6 §7.1
- **Set GSM EFR/HR/FR Codec** → `AT+QCFG="frhrcodec"` · QCFG V1.6 §7.2
- **Set PDP Authentication Type in BIP Process** → `AT+QCFG="bip/auth"` · QCFG V1.6 §7.3
- **List Message Map** → `AT+QCFG="SMS/ListMsgMap"` · QCFG V1.6 §7.4
- **Enable/Disable IMS/UT Function** → `AT+QCFG="ims/ut"` · QCFG V1.6 §7.5
- **IMS/VoLTE config** — `AT+QCFG="ims"` · QCFG V1.6 §7.6
  - Force enable IMS/VoLTE → `AT+QCFG="ims",1`
  - Restore default IMS (follow MBN) → `AT+QCFG="ims",0`
  - Force disable IMS → `AT+QCFG="ims",2`
  - Query IMS/VoLTE config → `AT+QCFG="ims"`
- **Set SMS Format in LTE Mode** → `AT+QCFG="ltesms/format"` · QCFG V1.6 §7.7
- **Enable/Disable VoLTE** `[DANGER]` → `AT+QCFG="volte_disable"` · QCFG V1.6 §7.8
- **Set OMADM Message Parsing Mode** → `AT+QCFG="sms/omadm"` · QCFG V1.6 §7.9
- **Configurethe IP Typefor IMS Registration** → `AT+QCFG="imsreg/iptype"` · QCFG V1.6 §7.10
- **Set (U)SIM Card Hot-plug** → `AT+QCFG="sim/recovery"` · QCFG V1.6 §7.11
- **Enable/Disable Re -attach Request** → `AT+QCFG="siminvalirecovery"` · QCFG V1.6 §7.12
- **Enable/Disable Voice Call in Roaming Mode** → `AT+QCFG="roaming/voicecall"` · QCFG V1.6 §7.13
- **Set Busy Tone Playback** → `AT+QCFG="voice_busytone"` · QCFG V1.6 §7.14

#### 8 PPP Command

- **Enable/Disable PPP TERM Frame Sending** → `AT+QCFG="ppp/termframe"` · QCFG V1.6 §8.1

#### 9 USB Commands

- **USB net mode** — `AT+QCFG="usbnet"` · QCFG V1.6 §9.1
  - Set USB net to QMI/RmNet → `AT+QCFG="usbnet",0`
  - Set USB net to ECM → `AT+QCFG="usbnet",1`
  - Set USB net to MBIM → `AT+QCFG="usbnet",2`
  - Set USB net to RNIDS → `AT+QCFG="usbnet",3`
  - Query USB net mode → `AT+QCFG="usbnet"`
- **Set VID, PID and Porting Settings** → `AT+QCFG="usbcfg"` · QCFG V1.6 §9.2
- **Set USB Device Loading** → `AT+QCFG="usbee"` · QCFG V1.6 §9.3
- **Get USB Mode** → `AT+QCFG="usbmode"` · QCFG V1.6 §9.4
- **Set SPI or UART Driver** → `AT+QCFG="spi/set"` · QCFG V1.6 §9.5
- **Enable USB Enumeration Failure Optimization** → `AT+QCFG="usbenum/seoctl"` · QCFG V1.6 §9.6

#### 10 CDMA Commands

- **Set PPP Authentication Optimization under CDMA** → `AT+QCFG="cdma/pppauth"` · QCFG V1.6 §10.1
- **Configure CDMA Mode** → `AT+QCFG="ehrpd"` · QCFG V1.6 §10.2
- **Set CMT Format of CDMA SMS PDU** → `AT+QCFG="cdmasms/cmtformat"` · QCFG V1.6 §10.3

#### 11 SMS Commands

- **Set URC Output Port of Short Message** → `AT+QCFG="urcport/sms"` · QCFG V1.6 §11.1
- **Enable/Disable Delivering or Submitting SMS** → `AT+QCFG="sms_control"` · QCFG V1.6 §11.3

### QSIMCFG V1.0

#### 2 QSIMCFG Commands

- **(U)SIM Card Configuration** `[DANGER]` — `AT+QSIMCFG` · QSIMCFG V1.0 §2.3.1
  - (U)SIM Card Configuration → `AT+QSIMCFG`
  - Enable/Disable Physical (U)SIM `[DANGER]` → `AT+QSIMCFG="disable_physim"`
  - 查询 SIM 卡的应用类型 → `AT+QSIMCFG="app_type"`
  - 查询 SIM 卡的复位应答（ATR） → `AT+QSIMCFG="atr"`
  - 查询 M2MeSIM 的 EID → `AT+QSIMCFG="eid"`
  - 查询当前卡槽的状态 → `AT+QSIMCFG="slot_status"`
  - 查询 eSIM SGP 版本号 → `AT+QSIMCFG="esim_svn"`

## Dangerous commands

| Purpose | Command | Notes | Ref |
|---------|---------|-------|-----|
| Enable/disable (U)SIM | `AT+QSIMCFG="disable_physim"` | Can disable the physical SIM. | QSIMCFG V1.0 |
| Send SMS | `AT+CMGS` | Risk of sending SMS by mistake. | AT Manual V2.2 §9.8 |
| Enable/disable VoLTE (alternate switch) | `AT+QCFG="volte_disable"` | Different from AT+QCFG="ims"; easy to confuse. | QCFG V1.6 §7.8 |
| Factory-reset AT settings | `AT&F` | Resets AT settings — confirm before use. | AT Manual V2.2 §2.10 |
| Power off module | `AT+QPOWD` | Powers off the module. | AT Manual V2.2 §13 |
| Delete SMS | `AT+CMGD` | Deletes stored messages. | AT Manual V2.2 §9.5 |
| Send SMS from storage | `AT+CMSS` | Actually transmits an SMS. | AT Manual V2.2 §9.11 |
| Send concatenated SMS | `AT+QCMGS` | Risk of sending SMS by mistake. | AT Manual V2.2 §9.17 |
| Delete MBN file | `AT+QMBNCFG="Delete"` | May break operator config. | AT Manual V2.2 §4.4.6 |
| Switch SIM slot | `AT+QDSIM` | Switches SIM slot; may drop network. | AT Manual V2.2 §5.12 |
| Write IMEI | `AT+EGMR` | Rewrites module IMEI — confirm the number is correct. | Quectel EGMR |

