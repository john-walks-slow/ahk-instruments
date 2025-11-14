; ==================================================================================================
; == Chord Engine
; ==================================================================================================

; Main function to calculate and play the current chord.
UpdateChord() {
    global
    oldNotes := g_SoundingChordNotes.Clone()
    targetNotes := BuildChordFromDef(g_CurrentChordDef)

    ; Add notes from any active followups (chord extensions)
    for _, notesArray in g_ChordExtensionNotes {
        for _, note in notesArray {
            targetNotes.Push(note)
        }
    }
    
    voicedNotes := ApplyVoicing(targetNotes, g_ActiveVoicing)
    SortArray(voicedNotes)
    g_SoundingChordNotes := voicedNotes

    if g_IsArpOn {
        StartArp()
    } else {
        notesToStop := [], notesToPlay := []
        ; Determine which old notes to stop
        for oldNote in oldNotes {
            isStillPlaying := false
            for newNote in g_SoundingChordNotes
                if (oldNote = newNote)
                    isStillPlaying := true
            if !isStillPlaying
                notesToStop.Push(oldNote)
        }
        ; Determine which new notes to play
        for newNote in g_SoundingChordNotes {
            wasAlreadyPlaying := false
            for oldNote in oldNotes
                if (newNote = oldNote)
                    wasAlreadyPlaying := true
            if !wasAlreadyPlaying
                notesToPlay.Push(newNote)
        }
        ; Send MIDI messages
        for note in notesToStop
            NoteOff(note)
        for note in notesToPlay
            NoteOn(note)
    }
}

; Stops the currently sounding chord.
StopChord() {
    global
    if (g_IsLatchOn) {
        g_LatchedChordNotes := g_SoundingChordNotes.Clone()
    } else {
        for note in g_SoundingChordNotes
            NoteOff(note)
    }
    StopArp()
    g_SoundingChordNotes := []
    g_CurrentChordDef := ""
    g_ActiveChordHotkey := ""
    g_ChordExtensionNotes.Clear()
}

; Calculates the final chord notes from a definition.
BuildChordFromDef(definition) {
    global
    if (definition = "")
        return []
    
    param := definition.param
    
    ; 1. Determine Root Note
    degreeStr := RegExReplace(param.root, "i") ; Get roman numeral without case
    degree := g_RomanMap.Get(degreeStr)
    rootOffset := g_MajorScale[degree]
    
    quality := ""
    if (param.Has("quality"))
        quality := param.quality
    else ; Infer from case
        quality := (param.root == degreeStr) ? "min" : "Maj" ; I is Maj, i is min

    octaveOffset := param.Has("octaveOffset") ? param.get("octaveOffset") * 12 : 0
    rootNote := g_ScaleRoot + g_Transpose + g_ChordTranspose + rootOffset + octaveOffset

    ; 2. Determine Intervals
    intervals := ParseIntervals(param.shape)

    ; 3. Build root position chord
    finalNotes := []
    for interval in intervals
        finalNotes.Push(rootNote + interval)
    
    return finalNotes
}

; Applies a voicing preset to a set of chord notes.
ApplyVoicing(rootChordNotes, preset) {
    global
    if (preset.Length = 0 || rootChordNotes.Length = 0)
        return rootChordNotes

    voicedChord := []
    for _, voiceDef in preset {
        toneIndex := voiceDef[1]
        octaveShift := voiceDef[2]

        if (toneIndex > rootChordNotes.Length)
            continue

        baseNoteForTone := rootChordNotes[toneIndex]
        finalNote := baseNoteForTone + (octaveShift * 12)
        voicedChord.Push(finalNote)
    }
    return voicedChord
}