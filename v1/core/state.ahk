; ==================================================================================================
; == 全局状态变量 (Global State)
; ==================================================================================================
; --- Transposition Offsets (in semitones) ---
global g_GlobalTranspose := 0, g_ChordTranspose := 0 ; Global and Chord-only offsets
; Chord State
global g_HeldChordKeys := []                                 ; Keys currently held down for chord recognition
global g_SoundingChordNotes := []                            ; MIDI notes currently ON from the chord function OR notes for the arpeggiator
global g_HeldChord_by_Capslock := []                         ; Notes latched by CapsLock
global g_IsChordLatchOn := false                             ; CapsLock state
global g_ActiveVoicingKey := "Numpad0"                       ; Key of the currently selected voicing preset
; Arpeggiator State
global g_IsArpOn := false, g_ArpTimerObj := "", g_ArpPatternKey := "Numpad1"
global g_ArpCurrentStep := 1, g_ArpRate := 125 ; ms, e.g., 120BPM 16ths
global g_ArpLastNote := -1
; Note Tracking
global g_SoundingNotes := Map()                              ; Map<MIDI_Note, Count> for polyphony and note-off
global g_MelodyKeysDown := Map()                             ; Map<Key, MIDI_Note> for melody key tracking
