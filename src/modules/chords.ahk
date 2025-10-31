; ==================================================================================================
; == 和弦处理逻辑 (Chord Handling Logic)
; ==================================================================================================

; Handles key down/up events for all chord and voicing keys
ChordKeyHandler(key, state, *) {
    global
    if (state = "down") {
        ; Stop latched chord if a new key is pressed (unless it's a voicing key)
        if g_HeldChord_by_Capslock.Length > 0 && !VOICING_PRESETS.Has(key) {
            for note in g_HeldChord_by_Capslock
                NoteOff(note)
            g_HeldChord_by_Capslock := []
            g_SoundingChordNotes := []
        }

        ; If the pressed key is a voicing preset, it might change voicing or arp pattern.
        if VOICING_PRESETS.Has(key) {
            if g_IsArpOn && ARP_PATTERNS.Has(key) {
                g_ArpPatternKey := key
                Tooltip "Arp Pattern: " key, , , 2
                SetTimer () => Tooltip(, , , 2), -1000
                StartArp() ; Restart arp with new pattern
            } else if !g_IsArpOn {
                g_ActiveVoicingKey := key
                UpdateChord() ; Re-render the chord with new voicing
            }
            return
        }

        ; Prevent duplicates in held keys
        for heldKey in g_HeldChordKeys
            if heldKey = key
                return
        g_HeldChordKeys.Push(key)

        ; Set the base key (root key) if it's the first chord key pressed
        if (g_ChordBaseKey = "" && KEY_TO_CHORD.Has(key))
            g_ChordBaseKey := key

        UpdateChord()

    } else { ; "up"
        isBaseKey := (key = g_ChordBaseKey)
        keyFound := false
        loop g_HeldChordKeys.Length {
            if g_HeldChordKeys[A_Index] = key {
                g_HeldChordKeys.RemoveAt(A_Index)
                keyFound := true
                break
            }
        }

        if !keyFound
            return

        ; If the key released is a voicing key, do nothing but exit
        if VOICING_PRESETS.Has(key)
            return

        ; Latch behavior
        if g_IsChordLatchOn {
            if g_HeldChordKeys.Length = 0 {
                ; Latch the currently sounding notes
                g_HeldChord_by_Capslock := g_SoundingChordNotes.Clone()
                g_ChordBaseKey := ""
            }
        } else {
            ; Non-latch behavior: remove base key if released, then update
            if isBaseKey {
                g_ChordBaseKey := ""
            }
            UpdateChord()
        }
    }
}

; Determines and plays the new chord notes, stopping old ones
UpdateChord() {
    global
    oldNotes := g_SoundingChordNotes.Clone()
    targetNotes := BuildChordFromHeldKeys()
    g_SoundingChordNotes := targetNotes

    if g_IsArpOn {
        StopArp()
        StartArp()
    } else {
        notesToStop := [], notesToPlay := []
        ; Determine which old notes to stop
        for oldNote in oldNotes {
            isStillPlaying := false
            for newNote in targetNotes
                if (oldNote = newNote)
                    isStillPlaying := true
            if !isStillPlaying
                notesToStop.Push(oldNote)
        }
        ; Determine which new notes to play
        for newNote in targetNotes {
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

; --- Calculates the final chord notes ---
BuildChordFromHeldKeys() {
    global
    if (g_ChordBaseKey = "" || !KEY_TO_CHORD.Has(g_ChordBaseKey))
        return []

    chordDef := KEY_TO_CHORD.get(g_ChordBaseKey)
    scaleDegree := chordDef.get("Root")
    baseQuality := chordDef.get("Quality")
    chordType := chordDef.get("Type")
    octaveShift := chordDef.Has("OctaveShift") ? chordDef.get("OctaveShift") : 0

    ; --- Calculate root note using unified transpose variables ---
    rootNote := 60 + g_GlobalTranspose + g_ChordTranspose + MAJOR_SCALE[scaleDegree] + (octaveShift * 12)

    ; --- Build chord with additive extensions ---
    ; 1. Start with base triad intervals
    intervals := CHORD_FORMULAS.get(baseQuality).Clone()

    ; 2. Add intervals from modifier keys
    if chordDef.Has("Modifiers") {
        for key in g_HeldChordKeys {
            if chordDef.get("Modifiers").Has(key) {
                degree := chordDef.get("Modifiers").get(key)
                if EXTENSION_INTERVALS.get(chordType).Has(degree) {
                    intervals.Push(EXTENSION_INTERVALS.get(chordType).get(degree))
                }
            }
        }
    }
    SortVoicedChord(intervals) ; Sort intervals to ensure ToneIndex is consistent (1=root, 2=3rd, 3=5th, etc.)

    ; 3. Build the "root" chord (all tones from formula, starting at rootNote)
    rootChord := []
    for interval in intervals
        rootChord.Push(rootNote + interval)
    if rootChord.Length = 0
        return []

    ; --- Apply active voicing preset, supporting both Map and Array formats ---
    voicingConfig := VOICING_PRESETS.get(g_ActiveVoicingKey)
    numNotes := rootChord.Length
    presetArray := []

    if (Type(voicingConfig) = "Map") { ; Original format: Map(NumNotes, Preset)
        if voicingConfig.Has(numNotes)
            presetArray := voicingConfig.get(numNotes)
    } else { ; New format: Preset is a single Array
        presetArray := voicingConfig
    }

    if (presetArray.Length > 0) {
        return ApplyVoicing(rootChord, presetArray)
    }

    return rootChord ; Return root position chord if no valid voicing is found
}

; Applies the voicing rules (ToneIndex and OctaveShift) to the root chord
; rootChord: [Note_Root, Note_3rd, Note_5th, ...]
; preset: [[ToneIndex, OctaveShift], ...]
ApplyVoicing(rootChord, preset) {
    global
    voicedChord := []
    for _, voiceDef in preset {
        toneIndex := voiceDef[1] ; The 'Tone' (1=Root, 2=3rd, etc.)
        octaveShift := voiceDef[2] ; The 'Octave' shift (-1, 0, 1, etc.)

        ; Ensure the tone exists in the root chord (e.g., prevent using a 7th in a triad)
        if (toneIndex > rootChord.Length)
            continue

        baseNoteForTone := rootChord[toneIndex]
        finalNote := baseNoteForTone + (octaveShift * 12)
        voicedChord.Push(finalNote)
    }
    SortVoicedChord(voicedChord)
    return voicedChord
}

; Hotkey registration for all chord and voicing keys
allChordFunctionKeys := Map()
for baseKey, chordDef in KEY_TO_CHORD {
    allChordFunctionKeys.set(baseKey, true)
    if chordDef.Has("Modifiers")
        for modifierKey in chordDef.get("Modifiers")
            allChordFunctionKeys.set(modifierKey, true)
}
for key in VOICING_PRESETS
    allChordFunctionKeys.set(key, true)

for key in allChordFunctionKeys {
    down_func := ChordKeyHandler.Bind(key, "down")
    up_func := ChordKeyHandler.Bind(key, "up")
    Hotkey key, down_func
    Hotkey key " Up", up_func
}
