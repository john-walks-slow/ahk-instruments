#SingleInstance force
#Include <jsongo.v2>
#Include <MIDIv2>

; ==================================================================================================
; == Core Components
; ==================================================================================================
#Include core\state.ahk
#Include core\utils.ahk
#Include core\midi_io.ahk
#Include core\config_parser.ahk

; ==================================================================================================
; == Functional Modules
; ==================================================================================================
#Include modules\actions.ahk
#Include modules\chord_engine.ahk
#Include modules\arpeggiator.ahk
#Include modules\input_handler.ahk

; ==================================================================================================
; == Initialization
; ==================================================================================================
Init() {
    global
    LoadConfig()      ; Load and parse config.json5
    InitMidi()        ; Initialize MIDI output
    RegisterHotkeys() ; Set up the input handling
    Tooltip("MidiAHK v2 Ready", , , 1)
    SetTimer(() => Tooltip(, , , 1), -2000)
}

Init()