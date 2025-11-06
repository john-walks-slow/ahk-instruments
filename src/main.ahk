#SingleInstance force
#Include ../lib/MIDIv2.ahk

; 1. 全局状态
#Include core\state.ahk

; 2. 数据配置
#Include config\theory.ahk
#Include config\voicings.ahk
#Include config\arp_patterns.ahk
#Include config\chord_mappings.ahk
#Include config\melody_map.ahk

; 3. 核心功能库
#Include core\utils.ahk
#Include core\midi_io.ahk

; 4. 功能模块
HotIf(IsEnabled)
#Include modules\system.ahk
#Include modules\chords.ahk
#Include modules\arpeggiator.ahk
#Include modules\melody.ahk
HotIf()