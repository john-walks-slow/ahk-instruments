; ==================================================================================================
; == 琶音器逻辑 (Arpeggiator Logic)
; ==================================================================================================

StartArp() {
    global
    StopArp() ; Ensure any previous arp is stopped
    if !g_IsArpOn || g_SoundingChordNotes.Length = 0
        return

    g_ArpCurrentStep := 1
    g_ArpTimerObj := SetTimer(ArpTick, g_ArpRate)
    ArpTick() ; Trigger the first note immediately
}

StopArp() {
    global
    if IsObject(g_ArpTimerObj)
        SetTimer(g_ArpTimerObj, 0)
    g_ArpTimerObj := ""

    if (g_ArpLastNote != -1) {
        NoteOff(g_ArpLastNote)
        g_ArpLastNote := -1
    }
}

ArpTick() {
    global
    ; Stop if arp is off or no chord is held
    if !g_IsArpOn || g_SoundingChordNotes.Length = 0 {
        StopArp()
        return
    }

    ; Turn off the last note
    if (g_ArpLastNote != -1)
        NoteOff(g_ArpLastNote)

    numNotes := g_SoundingChordNotes.Length
    pattern := ARP_PATTERNS.get(g_ArpPatternKey)
    noteIndex := 0

    if (g_ArpPatternKey = "Numpad6") { ; Random pattern
        noteIndex := Random(1, numNotes)
    } else { ; Indexed pattern
        patternStep := Mod(g_ArpCurrentStep - 1, pattern.Length) + 1
        noteIndex := pattern[patternStep]
        ; Wrap index if pattern goes higher than available notes
        noteIndex := Mod(noteIndex - 1, numNotes) + 1
    }

    noteToPlay := g_SoundingChordNotes[noteIndex]
    NoteOn(noteToPlay)
    g_ArpLastNote := noteToPlay
    g_ArpCurrentStep++
}

ToggleArp(*) {
    global
    g_IsArpOn := !g_IsArpOn

    if g_IsArpOn {
        ; Turning ON: Stop sustained notes and start arp
        for note in g_SoundingChordNotes
            NoteOff(note)
        StartArp()
    } else {
        ; Turning OFF: Stop arp and play sustained notes
        StopArp()
        for note in g_SoundingChordNotes
            NoteOn(note)
    }

    stateText := g_IsArpOn ? "ON" : "OFF"
    Tooltip "Arpeggiator: %stateText%", , , 2
    SetTimer () => Tooltip(, , , 2), -1500
}

Hotkey "F1", ToggleArp