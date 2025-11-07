; ==================================================================================================
; == 旋律键盘逻辑 (Melody Keyboard Logic)
; ==================================================================================================

; Handles key down/up events for melody keys
HandleMelodyKey(key, state, *) {
    global
    if !MELODY_MAP.Has(key)
        return
    interval := MELODY_MAP.get(key)
    noteToPlay := 60 + g_GlobalTranspose + interval

    if (state = "down") {
        if !g_MelodyKeysDown.Has(key) {
            ; Check if the note is already on (from a chord or another melody key)
            isAlreadyOn := g_SoundingNotes.Has(noteToPlay) && g_SoundingNotes.get(noteToPlay) > 0
            if isAlreadyOn
                ; Send a NoteOff for the existing note to allow retriggering
                MIDI.SendNoteOff(noteToPlay, 0, MIDI_CHANNEL)

            MIDI.SendNoteOn(noteToPlay, VELOCITY, MIDI_CHANNEL)

            ; Update the counter (Handle the retrigger by adding a new count)
            count := isAlreadyOn ? g_SoundingNotes.get(noteToPlay) : 0
            g_SoundingNotes.set(noteToPlay, count + 1)
            g_MelodyKeysDown.set(key, noteToPlay)
        }
    } else { ; "up"
        if g_MelodyKeysDown.Has(key) {
            noteToStop := g_MelodyKeysDown.get(key)
            NoteOff(noteToStop) ; Use the safe NoteOff
            g_MelodyKeysDown.Delete(key)
        }
    }
}

; Hotkey registration for melody keys
for key in MELODY_MAP {
    down_func := HandleMelodyKey.Bind(key, "down")
    up_func := HandleMelodyKey.Bind(key, "up")
    Hotkey key, down_func
    Hotkey key " Up", up_func
}
