; ==================================================================================================
; == MIDI 配置与 I/O (MIDI Configuration & I/O)
; ==================================================================================================
global MIDI := MIDIv2()
global MIDI_CHANNEL := 1
global VELOCITY := 100
myOutputName := "loopMIDI Port"
myOutputID := GetOutputDeviceByName(myOutputName)
if (myOutputID = -1) {
    MsgBox("MIDI Output Device: " myOutputName " not found.`nPlease check your virtual MIDI setup (e.g., loopMIDI).")
    ExitApp
}
MIDI.OpenMidiOut(myOutputID)
OnExit(Cleanup)


GetOutputDeviceByName(name) {
    global
    outputDevices := MIDI.GetMidiOutDevices()
    loop outputDevices.Length
        if InStr(outputDevices[A_Index], name)
            return A_Index - 1
    return -1
}

; NoteOn function with polyphony tracking (increments count for the note)
NoteOn(note) {
    global
    count := g_SoundingNotes.Has(note) ? g_SoundingNotes.get(note) : 0
    if (count = 0)
        MIDI.SendNoteOn(note, VELOCITY, MIDI_CHANNEL)
    g_SoundingNotes.set(note, count + 1)
}

; NoteOff function with polyphony tracking (decrements count, sends NoteOff when count hits 0)
NoteOff(note) {
    global
    if !g_SoundingNotes.Has(note) || g_SoundingNotes.get(note) = 0
        return
    count := g_SoundingNotes.get(note) - 1
    if (count = 0) {
        MIDI.SendNoteOff(note, 0, MIDI_CHANNEL)
        g_SoundingNotes.Delete(note)
    } else {
        g_SoundingNotes.set(note, count)
    }
}

; Stops all sounding notes and resets global state
Panic() {
    global
    MIDI.SendControlChange(123, 0, MIDI_CHANNEL) ; All Notes Off CC
    StopArp()
    g_SoundingNotes.Clear(), g_SoundingChordNotes := []
    g_HeldChord_by_Capslock := [], g_MelodyKeysDown.Clear()
    g_IsChordLatchOn := false
}

Cleanup(*) {
    global
    Panic()
}