#SingleInstance force
#Include <MIDIv2>

; ==================================================================================================
; == 模块加载 (Module Loading)
; ==================================================================================================
; 模块加载顺序至关重要。
; 1. 全局状态
; 2. 数据配置 (音阶、和弦、声部等)
; 3. 核心功能库 (MIDI I/O, 工具函数)
; 4. 功能模块 (系统控制、和弦、琶音器、旋律)
; ==================================================================================================

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
#Include modules\system.ahk
#Include modules\chords.ahk
#Include modules\arpeggiator.ahk
#Include modules\melody.ahk

; 结束由 system.ahk 开启的 HotIf 上下文
HotIf()