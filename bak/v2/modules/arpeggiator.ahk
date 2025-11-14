; ==================================================================================================
; == Arpeggiator
; ==================================================================================================

StartArp() {
    global
    StopArp()
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
    if !g_IsArpOn || g_SoundingChordNotes.Length = 0 {
        StopArp()
        return
    }

    if (g_ArpLastNote != -1)
        NoteOff(g_ArpLastNote)

    numNotes := g_SoundingChordNotes.Length
    noteIndex := 0

    if (g_ArpPattern = "random") {
        noteIndex := Random(1, numNotes)
    } else {
        patternStep := Mod(g_ArpCurrentStep - 1, g_ArpPattern.Length) + 1
        noteIndex := g_ArpPattern[patternStep]
        noteIndex := Mod(noteIndex - 1, numNotes) + 1 ; Wrap index if pattern is larger than chord
    }

    noteToPlay := g_SoundingChordNotes[noteIndex]
    NoteOn(noteToPlay)
    g_ArpLastNote := noteToPlay
    g_ArpCurrentStep++
}