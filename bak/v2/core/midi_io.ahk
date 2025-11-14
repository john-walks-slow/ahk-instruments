; ==================================================================================================
; == MIDI I/O
; ==================================================================================================
global MIDI := ""
global MIDI_CHANNEL := 1
global VELOCITY := 100

InitMidi() {
    global
    OutputDebug("Initializing MIDI...")
    MIDI := MIDIv2()
    myOutputName := "loopMIDI Port"
    OutputDebug("Searching for MIDI Output Device: " myOutputName)
    myOutputID := GetOutputDeviceByName(myOutputName)
    if (myOutputID = -1) {
        MsgBox("MIDI Output Device: " myOutputName " not found.`nPlease check your virtual MIDI setup (e.g., loopMIDI).")
        OutputDebug("MIDI Initialization failed. Exiting.")
        ExitApp
    }
    OutputDebug("Opening MIDI Output Device ID: " myOutputID)
    MIDI.OpenMidiOut(myOutputID)
    OnExit(Cleanup)
}

GetOutputDeviceByName(name) {
    global
    outputDevices := MIDI.GetMidiOutDevices()
    OutputDebug("Available MIDI Output Devices:")
    loop outputDevices.Length {
        OutputDebug("  - " outputDevices[A_Index])
        if InStr(outputDevices[A_Index], name) {
            OutputDebug("Found matching device: " outputDevices[A_Index] " with ID: " A_Index - 1)
            return A_Index - 1
        }
    }
    OutputDebug("No matching MIDI device found for name: " name)
    return -1
}

; NoteOn function with polyphony tracking
NoteOn(note) {
    global
    count := g_SoundingNotes.Has(note) ? g_SoundingNotes.Get(note) : 0
    if (count = 0)
        MIDI.SendNoteOn(note, VELOCITY, MIDI_CHANNEL)
    g_SoundingNotes.Set(note, count + 1)
}

; NoteOff function with polyphony tracking
NoteOff(note) {
    global
    if !g_SoundingNotes.Has(note) || g_SoundingNotes.Get(note) = 0
        return
    count := g_SoundingNotes.Get(note) - 1
    if (count = 0) {
        MIDI.SendNoteOff(note, 0, MIDI_CHANNEL)
        g_SoundingNotes.Delete(note)
    } else {
        g_SoundingNotes.Set(note, count)
    }
}

; Stops all sounding notes immediately
Panic() {
    global
    MIDI.SendControlChange(123, 0, MIDI_CHANNEL) ; All Notes Off CC
    Sleep(50) ; Give MIDI devices a moment to process
    
    ; Clear all state
    StopArp()
    g_SoundingNotes.Clear()
    g_SoundingChordNotes := []
    g_LatchedChordNotes := []
    g_NoteActionSources.Clear()
    g_CurrentChordDef := ""
}

Cleanup(*) {
    Panic()
}