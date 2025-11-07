#Requires AutoHotkey v2.0
#SingleInstance force
#Include <MIDIv2>

global MIDI := MIDIv2()

; --- Configuration ---
MIDI_CHANNEL := 1
VELOCITY := 100
myOutputName := "loopMIDI Port"      ; <<< CHANGE THIS to the name of your MIDI Out port
myOutputID := GetOutputDeviceByName(myOutputName)
MIDI.OpenMidiOut(myOutputID)
OnExit(Cleanup) ; Register the cleanup function to run when the script exits

; ==================================================================================================
; == Harmonic Arpeggiator Engine - Global State
; ==================================================================================================
global g_CurrentKey := 60 ; 60 = C4. This is the root of our scale.
global g_CurrentOctave := 0 ; Adjusts the base octave up or down.

; ==================================================================================================
; == Core Functions
; ==================================================================================================

GetOutputDeviceByName(name) {
    global
    outputDevices := MIDI.GetMidiOutDevices()
    loop outputDevices.Length
        if outputDevices[A_Index] = name
            return A_Index - 1
    MsgBox("Output device: " name " is not available.")
    ExitApp
}

NoteOn(note) {
    global
    MIDI.SendNoteOn(note, VELOCITY, MIDI_CHANNEL)
}

NoteOff(note) {
    global
    MIDI.SendNoteOff(note, 0, MIDI_CHANNEL)
}

Panic() {
    global
    ; Send "All Notes Off" CC message to prevent stuck notes
    MIDI.SendControlChange(123, 0, MIDI_CHANNEL)
}

Cleanup(*) {
    global
    Panic() ; Call the panic function
    MsgBox("Piano script closing. All notes turned off.")
}

; ==================================================================================================
; == Hotkeys - The Instrument's Interface
; ==================================================================================================

; Create a condition where hotkeys are only active if ScrollLock is ON
#HotIf GetKeyState("ScrollLock", "T")

; --- System Controls ---
Esc:: Panic()
Up:: global g_CurrentKey += 1
Down:: global g_CurrentKey -= 1
Right:: global g_CurrentOctave += 1
Left:: global g_CurrentOctave -= 1

; --- Key Mapping Function (for Melody Mode) ---
MapPianoKey(Key, Note) {
    global
    Hotkey Key, (*) => NoteOn(Note + (g_CurrentOctave * 12) + g_CurrentKey)
    Hotkey Key " Up", (*) => NoteOff(Note + (g_CurrentOctave * 12) + g_CurrentKey)
}

; --- MELODY MODE MAPPINGSq ---
IsMelodyKeysEnabled(*) {
    global
    return GetKeyState("ScrollLock", "T")
}
HotIf(IsMelodyKeysEnabled)
; Lower Octave (White Keys)
MapPianoKey("Tab", 48)  ; C3
MapPianoKey("q", 50)    ; D3
MapPianoKey("w", 52)    ; E3
MapPianoKey("e", 53)    ; F3
MapPianoKey("r", 55)    ; G3
MapPianoKey("t", 57)    ; A3
MapPianoKey("y", 59)    ; B3
; Lower Octave (Black Keys)
MapPianoKey("1", 49)    ; C#3
MapPianoKey("2", 51)    ; D#3
MapPianoKey("4", 54)    ; F#3
MapPianoKey("5", 56)    ; G#3
MapPianoKey("6", 58)    ; A#3
; Middle Octave (White Keys)
MapPianoKey("u", 60)    ; C4
MapPianoKey("i", 62)    ; D4
MapPianoKey("o", 64)    ; E4
MapPianoKey("p", 65)    ; F4
MapPianoKey("[", 67)    ; G4
MapPianoKey("]", 69)    ; A4
MapPianoKey("\", 71)   ; B4
; Middle Octave (Black Keys)
MapPianoKey("8", 61)    ; C#4
MapPianoKey("9", 63)    ; D#4
MapPianoKey("-", 66)    ; F#4
MapPianoKey("=", 68)    ; G#4
MapPianoKey("Backspace", 70) ; A#4
; Upper Octave (White Keys)
MapPianoKey("Delete", 72)    ; C5
MapPianoKey("End", 74)       ; D5
MapPianoKey("PgDn", 76)      ; E5
MapPianoKey("Numpad7", 77)   ; F5
MapPianoKey("Numpad8", 79)   ; G5
MapPianoKey("Numpad9", 81)   ; A5
MapPianoKey("NumpadAdd", 83) ; B5
; Upper Octave (Black Keys)
MapPianoKey("Ins", 73)       ; C#5
MapPianoKey("Home", 75)      ; D#5
MapPianoKey("NumLock", 78)   ; F#5
MapPianoKey("NumpadDiv", 80) ; G#5
MapPianoKey("NumpadMult", 82) ; A#5
MapPianoKey("NumpadSub", 84) ; C6

HotIf()