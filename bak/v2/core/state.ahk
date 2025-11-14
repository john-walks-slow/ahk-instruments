; ==================================================================================================
; == Global State
; ==================================================================================================
global g_IsEnabled := true               ; Master switch
global g_Config := Map()                  ; Holds the parsed user configuration from config.json5
global g_Hotkeys := Map()                 ; Holds the processed, flattened hotkey definitions

; --- Input & Note State ---
global g_HeldKeys := Map()                ; Tracks currently pressed keys for modifier logic <KeyName, true>
global g_InputTimer := ""                 ; Timer for handling simultaneous key presses
global g_CombinationDelay := 10           ; ms delay to wait for key combinations
global g_SoundingNotes := Map()           ; Tracks all sounding notes for polyphony <MIDINote, Count>
global g_NoteActionSources := Map()       ; Tracks which key triggered a "note" action <KeyName, MIDINote>

; --- Chord & Voicing State ---
global g_ActiveChordHotkey := ""          ; The hotkey string that triggered the current chord
global g_CurrentChordDef := ""            ; The definition object for the currently held chord
global g_SoundingChordNotes := []         ; Final MIDI notes of the chord after voicing
global g_ChordExtensionNotes := Map()     ; Notes added by followup keys <FollowupKey, [Notes]>
global g_ActiveVoicing := []              ; The currently selected global voicing preset
global g_ActiveVoicingKey := "Numpad0"    ; The key that selected the current voicing

; --- Transposition ---
global g_Transpose := 0                   ; Global transpose in semitones
global g_ChordTranspose := 0              ; Chord-only transpose in semitones
global g_ScaleRoot := 60                  ; Base note for scale calculations (C4)
global g_MajorScale := [0, 2, 4, 5, 7, 9, 11]
global g_RomanMap := Map("I", 1, "II", 2, "III", 3, "IV", 4, "V", 5, "VI", 6, "VII", 7)

; --- Latch (Auto-Hold) ---
global g_IsLatchOn := false
global g_LatchedChordNotes := []

; --- Arpeggiator State ---
global g_IsArpOn := false
global g_ArpTimerObj := ""
global g_ArpPatternKey := "Numpad7"
global g_ArpPattern := [1, 2, 3, 4, 5, 6]
global g_ArpCurrentStep := 1
global g_ArpRate := 125 ; ms
global g_ArpLastNote := -1