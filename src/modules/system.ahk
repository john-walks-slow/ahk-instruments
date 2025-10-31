; ==================================================================================================
; == 全局开关与系统控制 (Global Toggle & System Controls)
; ==================================================================================================
IsEnabled(*) {
    global
    ; ScrollLock is the global MIDI switch (Toggle state)
    return GetKeyState("ScrollLock", "T")
}
HotIf(IsEnabled)

HandleEsc(*) {
    global
    Panic()
    MsgBox "Emergency Stop! All notes have been turned off."
}

; --- Adjusts the global transpose state ---
HandleTranspose(semitoneDelta, *) {
    global
    g_GlobalTranspose += semitoneDelta

    tooltipText := "Global Root: " GetNoteName(60 + g_GlobalTranspose) " (" g_GlobalTranspose " semi)"
    . "`nChord Offset: " g_ChordTranspose " semi"
    Tooltip tooltipText, , , 1
    SetTimer () => Tooltip(, , , 1), -2000 ; Hide after 2 seconds

    UpdateChord() ; Update chord to reflect the new transpose
}

; --- [REWRITTEN for Request 1] Adjusts the chord-only transpose state ---
HandleChordTranspose(semitoneDelta, *) {
    global
    g_ChordTranspose += semitoneDelta

    tooltipText := "Global Root: " GetNoteName(60 + g_GlobalTranspose) " (" g_GlobalTranspose " semi)"
    . "`nChord Offset: " g_ChordTranspose " semi"
    Tooltip tooltipText, , , 1
    SetTimer () => Tooltip(, , , 1), -2000 ; Hide after 2 seconds

    UpdateChord() ; Update chord to reflect the new transpose
}

; Toggles the chord latch functionality
CapsLockToggle(*) {
    global
    g_IsChordLatchOn := !g_IsChordLatchOn
    if (!g_IsChordLatchOn && g_HeldChord_by_Capslock.Length > 0) {
        ; Stop latched notes when turning latch OFF
        for note in g_HeldChord_by_Capslock
            NoteOff(note)
        g_HeldChord_by_Capslock := []
        g_SoundingChordNotes := []
    }

    ; Show a temporary tooltip for the latch state
    stateText := g_IsChordLatchOn ? "ON" : "OFF"
    Tooltip "Chord Latch: %stateText%", , , 2
    SetTimer () => Tooltip(, , , 2), -1500 ; Hide after 1.5 seconds
}

; System Control Hotkeys
Hotkey "Esc", HandleEsc
Hotkey "CapsLock", CapsLockToggle

; --- Global Transpose Hotkeys ---
Hotkey "Up", HandleTranspose.Bind(1)      ; Up arrow: +1 Semitone
Hotkey "Down", HandleTranspose.Bind(-1)   ; Down arrow: -1 Semitone
Hotkey "Right", HandleTranspose.Bind(12)   ; Right arrow: +1 Octave
Hotkey "Left", HandleTranspose.Bind(-12)  ; Left arrow: -1 Octave

; --- Chord-Only Transpose Hotkeys ---
Hotkey ">+Up", HandleChordTranspose.Bind(1)      ; RShift+Up: +1 Semitone (Chord Only)
Hotkey ">+Down", HandleChordTranspose.Bind(-1)   ; RShift+Down: -1 Semitone (Chord Only)
Hotkey ">+Right", HandleChordTranspose.Bind(12)   ; RShift+Right: +1 Octave (Chord Only)
Hotkey ">+Left", HandleChordTranspose.Bind(-12)  ; RShift+Left: -1 Octave (Chord Only)
