; ==================================================================================================
; == Actions
; ==================================================================================================

Action_Note(param, state, triggerKey) {
    global
    note := ParseNote(param)
    if (state = "down") {
        NoteOn(note)
        g_NoteActionSources.Set(triggerKey, note)
    } else {
        if (g_NoteActionSources.Has(triggerKey)) {
            noteToStop := g_NoteActionSources.Get(triggerKey)
            NoteOff(noteToStop)
            g_NoteActionSources.Delete(triggerKey)
        }
    }
}

Action_Chord(param, state, definition) {
    global
    if (state = "down") {
        ; Stop any previously sounding chord/latch before starting a new one.
        StopChord()

        ; This logic is now handled by StopChord(), but we'll clear the latched notes state just in case.
        if (g_IsLatchOn && g_LatchedChordNotes.Length > 0) {
            for note in g_LatchedChordNotes
                NoteOff(note)
            g_LatchedChordNotes := []
        }

        g_CurrentChordDef := definition
        g_ActiveChordHotkey := definition.hotkey
        UpdateChord()
    }
}

Action_ChordExtension(param, state, triggerKey) {
    global
    if (state = "down") {
        ; 1. Get Root Note of the current chord
        rootDef := g_CurrentChordDef.param
        degreeStr := RegExReplace(rootDef.root, "i")
        degree := g_RomanMap.Get(degreeStr)
        rootOffset := g_MajorScale[degree]
        octaveOffset := rootDef.Has("octaveOffset") ? rootDef.get("octaveOffset") * 12 : 0
        rootNote := g_ScaleRoot + g_Transpose + g_ChordTranspose + rootOffset + octaveOffset

        ; 2. Calculate extension notes from intervals
        intervals := ParseIntervals(param)
        addedNotes := []
        for interval in intervals
            addedNotes.Push(rootNote + interval)

        g_ChordExtensionNotes.Set(triggerKey, addedNotes)
        UpdateChord()
    } else { ; "up"
        if (g_ChordExtensionNotes.Has(triggerKey)) {
            g_ChordExtensionNotes.Delete(triggerKey)
            UpdateChord()
        }
    }
}

Action_SetVoicing(param, triggerKey) {
    global
    g_ActiveVoicing := param
    g_ActiveVoicingKey := triggerKey
    if (g_CurrentChordDef != "") {
        UpdateChord() ; Re-voice the current chord
    }
    Tooltip("Voicing: " triggerKey,,, 2)
    SetTimer(() => Tooltip(,,,2), -1500)
}

Action_SetTranspose(param) {
    global
    if (SubStr(param, 1, 1) = "+")
        g_Transpose += Integer(SubStr(param, 2))
    else if (SubStr(param, 1, 1) = "-")
        g_Transpose -= Integer(SubStr(param, 2))
    else if (SubStr(param, 1, 1) = "=")
        g_Transpose := Integer(SubStr(param, 2))
    
    DisplayTranspose()
}

Action_SetChordTranspose(param) {
    global
    if (SubStr(param, 1, 1) = "+")
        g_ChordTranspose += Integer(SubStr(param, 2))
    else if (SubStr(param, 1, 1) = "-")
        g_ChordTranspose -= Integer(SubStr(param, 2))
    else if (SubStr(param, 1, 1) = "=")
        g_ChordTranspose := Integer(SubStr(param, 2))
        
    DisplayTranspose()
    if (g_CurrentChordDef != "")
        UpdateChord()
}

Action_ToggleArp() {
    global
    g_IsArpOn := !g_IsArpOn
    if g_IsArpOn {
        for note in g_SoundingChordNotes
            NoteOff(note)
        StartArp()
    } else {
        StopArp()
        for note in g_SoundingChordNotes
            NoteOn(note)
    }
    stateText := g_IsArpOn ? "ON" : "OFF"
    Tooltip "Arpeggiator: " . stateText,,, 2
    SetTimer () => Tooltip(, , , 2), -1500
}

Action_SetArpPattern(param, triggerKey) {
    global
    g_ArpPattern := param
    g_ArpPatternKey := triggerKey
    if (g_IsArpOn) {
        StartArp() ; Restart with new pattern
    }
    Tooltip("Arp Pattern: " triggerKey,,, 2)
    SetTimer(() => Tooltip(,,,2), -1500)
}

Action_ToggleLatch() {
    global
    g_IsLatchOn := !g_IsLatchOn
    if (!g_IsLatchOn && g_LatchedChordNotes.Length > 0) {
        for note in g_LatchedChordNotes
            NoteOff(note)
        g_LatchedChordNotes := []
    }
    stateText := g_IsLatchOn ? "ON" : "OFF"
    Tooltip "Chord Latch: " . stateText,,, 2
    SetTimer () => Tooltip(, , , 2), -1500
}

DisplayTranspose() {
    global
    rootNoteName := "C" ; Placeholder, can be improved to get actual note name
    tooltipText := "Global Root: " g_Transpose " semi`n"
    . "Chord Offset: " g_ChordTranspose " semi"
    Tooltip tooltipText, , , 1
    SetTimer () => Tooltip(, , , 1), -2000
}