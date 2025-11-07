#Requires AutoHotkey v2.0
#SingleInstance force
; Assumes MIDIv2.ahk and JSON.ahk are in the AHK library or script directory.
#Include Libs\MIDIv2.ahk
; #Include <JSON> ; Uncomment and ensure JSON.ahk is available if loading from file.

; ==================================================================================================
; == Configuration and Initialization
; ==================================================================================================

global MIDI := MIDIv2()

; --- Core Settings ---
MIDI_CHANNEL := 1
VELOCITY := 100
myOutputName := "loopMIDI Port" ; <<< CHANGE THIS to the name of your MIDI Out port
myOutputID := GetOutputDeviceByName(myOutputName)
MIDI.OpenMidiOut(myOutputID)
OnExit(Cleanup)

; --- Global State ---
global g_GlobalTranspose := 0    ; Total semitones offset from C4 (0-127)
global g_ChordTranspose := 0     ; Additional semitones offset for chords (for borrowing)
global g_CurrentVoicing := [1, 0, 1, 1, 1, 1] ; Default Voicing
global g_AutoHoldState := "off"  ; "on", "off"
global g_AutoHoldMode := "chord" ; "chord", "melody", "all"
global g_MemorizeVoicing := "off" ; "on", "off"
global g_HeldChords := Map()     ; Map<Key/Mode, List<NoteNumbers>> for AutoHold
global g_PlayingChords := Map()  ; Map<TriggerKey, List<NoteNumbers>> for currently sounding notes
global g_MemorizedVoicings := Map() ; Map<TriggerKey, VoicingArray>
global g_SimultaneousPresses := Map() ; Map<Key, Time> for Modifier logic
global g_SimultaneousWindow := 10  ; ms to consider keys pressed simultaneously
global g_PendingChords := Map()  ; Map<Key, TimerObject> for delayed chord triggering

; --- Musical Constants (Semi-tone offsets) ---
global g_Intervals := Map(
    "P1", 0, "m2", 1, "M2", 2, "m3", 3, "M3", 4, "P4", 5, "A4", 6, "d5", 6,
    "P5", 7, "m6", 8, "M6", 9, "m7", 10, "M7", 11, "P8", 12, "M9", 14, "M11", 17, "P11", 17
)
global g_RomanNumerals := Map("Ⅰ", 0, "Ⅱ", 2, "Ⅲ", 4, "Ⅳ", 5, "Ⅴ", 7, "Ⅵ", 9, "Ⅶ", 11)

; ==================================================================================================
; == Configuration
; ==================================================================================================

; Placeholder for the JSON config["ration"] structure
global g_Config := Map(
    ; --- Single Note Trigger ---
    'q', Map('action', 'note', 'param', 'C5'),
    ; --- Chord Triggers ---
    'z', Map(
        'action', 'chord',
        'param', Map(
            'root', 'Ⅰ', 'octaveOffset', 0, 'shape', ['P1', 'M3', 'P5'],
            'modifiers', Map(
                'x', 'P1,M3,P5,M7', 'c', 'P1,M2,P5', 'v', 'P1,P4,P5',
                'xc', 'P1,M3,P5,M7,M9'
            ),
            'followups', Map('x', 'M7', 'c', 'M9', 'v', 'M11')
        )
    ),
    ; --- Verbose-Syntax Modifiers (Processed as separate hotkeys) ---
    'z & x', Map('action', 'chord', 'param', Map('root', 'Ⅰ', 'octaveOffset', 0, 'shape', ['P1', 'M3', 'P5', 'M7'])),
    'z & x & c', Map('action', 'chord', 'param', Map('root', 'Ⅰ', 'octaveOffset', 0, 'shape', ['P1', 'M3', 'P5', 'M7',
        'M9'])),
    'z & c', Map('action', 'chord', 'param', Map('root', 'Ⅰ', 'octaveOffset', 0, 'shape', ['P1', 'M2', 'P5'])),
    ; --- Followup Action (Verbose syntax) ---
    'z - x', Map('action', 'chordExtension', 'param', ['M7']),
    ; --- Control Actions ---
    'numpad5', Map('action', 'setVoicing', 'param', [1, 0, 1, 1, 1, 1]),
    'numpadDel', Map('action', 'memorizeVoicing', 'param', 'cycle'),
    'shift + numpadDel', Map('action', 'clearMemorizedVoicing'),
    'left', Map('action', 'setTranspose', 'param', '-1'),
    'shift + left', Map('action', 'setChordTranspose', 'param', '-1'),
    'capslock', Map('action', 'setAutoHold', 'param', 'cycle'),
    'shift + capslock', Map('action', 'setAutoHoldMode', 'param', 'cycle')
)

; ==================================================================================================
; == Helpers
; ==================================================================================================

GetOutputDeviceByName(name) {
    global
    outputDevices := MIDI.GetMidiOutDevices()
    loop outputDevices.Length
        if outputDevices[A_Index] = name
            return A_Index - 1
    MsgBox("Output device: " name " is not available.")
    ExitApp
}

NoteOn(note, vel := VELOCITY) {
    global MIDI, MIDI_CHANNEL, VELOCITY
    MIDI.SendNoteOn(note, vel, MIDI_CHANNEL)
}

NoteOff(note) {
    global MIDI, MIDI_CHANNEL
    MIDI.SendNoteOff(note, 0, MIDI_CHANNEL)
}

Panic() {
    global MIDI, MIDI_CHANNEL, g_PlayingChords, g_HeldChords
    for triggerKey, notes in g_PlayingChords {
        for index, note in notes {
            NoteOff(note)
        }
    }
    g_PlayingChords := Map()
    g_HeldChords := Map()
    MIDI.SendControlChange(123, 0, MIDI_CHANNEL)
}

Cleanup(*) {
    global
    Panic()
    MsgBox("Instrument closing. All notes turned off.")
}

; Function to get the current chord shape based on modifiers
GetChordShape(triggerKey, config) {
    global g_SimultaneousPresses, g_SimultaneousWindow, g_Config

    ; 1. Check for Verbose Syntax 'T & M1 & M2'
    ; This is handled by the main hotkey loop registering the full combination.
    ; This function only handles the *short* syntax lookup.

    chordConfig := config["param"]
    baseShape := chordConfig.shape

    ; 2. Check for Short Syntax Modifiers
    modifiersConfig := chordConfig.modifiers
    if (!modifiersConfig) {
        return baseShape
    }

    simultaneousKeys := []
    triggerTime := g_SimultaneousPresses[triggerKey]

    ; Find keys pressed simultaneously within the tolerance window
    for key, time in g_SimultaneousPresses {
        if (key != triggerKey && Abs(time - triggerTime) <= g_SimultaneousWindow)
            simultaneousKeys.Push(key)
    }

    if (simultaneousKeys.Length > 0) {
        simultaneousKeys.Sort(1)
        modifierString := ""
        for index, key in simultaneousKeys {
            modifierString .= key
        }

        if (modifiersConfig.Has(modifierString)) {
            ; Convert comma-separated string to an array
            return StrSplit(modifiersConfig[modifierString], ",")
        }
    }
    return baseShape
}

IntervalsToSemitones(intervals) {
    global g_Intervals
    semitones := []
    for index, interval in intervals {
        if (g_Intervals.Has(interval)) {
            semitones.Push(g_Intervals[interval])
        }
    }
    return semitones
}

ResolveRoot(root) {
    global g_RomanNumerals
    return g_RomanNumerals.Has(root) ? g_RomanNumerals[root] : 0
}

; ==================================================================================================
; == Action Handlers
; ==================================================================================================

; The core function that calculates and plays chord notes.
ResolveAndPlayChord(key, config) {
    global g_GlobalTranspose, g_ChordTranspose, g_CurrentVoicing, g_MemorizedVoicings
    global g_PlayingChords, g_HeldChords, g_PendingChords

    ; Cancel any pending action for this key
    if (g_PendingChords.Has(key)) {
        ClearTimeout(g_PendingChords[key])
        g_PendingChords.Delete(key)
    }

    chordConfig := config["param"]

    ; 1. Get Base Chord Shape (considering Modifiers)
    shapeIntervals := GetChordShape(key, config)
    semitones := IntervalsToSemitones(shapeIntervals)
    chordRootOffset := ResolveRoot(chordConfig.root)

    ; 2. Determine Voicing
    voicing := g_MemorizedVoicings.Has(key) ? g_MemorizedVoicings[key] : g_CurrentVoicing

    ; 3. Apply Voicing, Transpose, and Octave Offset to get Note Numbers
    noteNumbers := []
    ; Base note is C4 (60) + Global Transpose + Chord Transpose + Roman Numeral Root + Octave Offset
    baseNote := 60 + g_GlobalTranspose + g_ChordTranspose + chordRootOffset + (chordConfig.octaveOffset * 12)

    for index, semitone in semitones {
        voicingIndex := Mod(index - 1, voicing.Length) + 1
        octaveOffset := voicing[voicingIndex]
        noteNumbers.Push(baseNote + semitone + (octaveOffset * 12))
    }

    ; --- AutoHold / Latch Logic ---
    if (g_AutoHoldState == "on" && (g_AutoHoldMode == "chord" || g_AutoHoldMode == "all")) {
        ; Release previous held chord
        if (g_HeldChords.Has("CHORD")) {
            for index, note in g_HeldChords["CHORD"] {
                NoteOff(note)
            }
        }
        g_HeldChords["CHORD"] := noteNumbers
    }

    ; 4. Play Notes
    for index, note in noteNumbers {
        NoteOn(note)
    }
    g_PlayingChords[key] := noteNumbers

    ; Note: Followups (ChordExtension) are not implemented in this delayed function.
    ; They would rely on a separate hotkey trigger ('z - x').
}

HandleNoteAction(key, config, isKeyDown) {
    global g_GlobalTranspose, g_AutoHoldState, g_AutoHoldMode, g_HeldChords

    noteNumber := MIDI.NoteName2Number(config["param"])
    finalNote := noteNumber + g_GlobalTranspose

    if (isKeyDown) {
        if (g_AutoHoldState == "on" && (g_AutoHoldMode == "melody" || g_AutoHoldMode == "all")) {
            if (g_HeldChords.Has("MELODY")) {
                for index, note in g_HeldChords["MELODY"] {
                    NoteOff(note)
                }
            }
            g_HeldChords["MELODY"] := [finalNote]
            NoteOn(finalNote)
        } else {
            NoteOn(finalNote)
            ; Basic note release will be handled by ChordEngine_KeyUp
            g_PlayingChords[key] := [finalNote]
        }
    } else { ; Key Up
        if (g_AutoHoldState == "on" && (g_AutoHoldMode == "melody" || g_AutoHoldMode == "all")) {
            ; Do not release, it's held until next note/chord.
        } else {
            if (g_PlayingChords.Has(key)) {
                NoteOff(finalNote)
                g_PlayingChords.Delete(key)
            }
        }
    }
}

HandleChordAction(key, config, isKeyDown) {
    global g_SimultaneousWindow, g_PendingChords, g_SimultaneousPresses
    global g_PlayingChords, g_AutoHoldState, g_AutoHoldMode

    if (isKeyDown) {
        ; --- DELAY LOGIC FOR SIMULTANEOUS DETECTION ---
        ; This is the key change: delay the action to allow modifiers to register.
        timerObj := SetTimeout(ResolveAndPlayChord, g_SimultaneousWindow, key, config)
        g_PendingChords[key] := timerObj
    } else { ; Key Up
        ; If chord is pending, cancel it immediately (prevents playing a chord on up if keyup is fast)
        if (g_PendingChords.Has(key)) {
            ClearTimeout(g_PendingChords[key])
            g_PendingChords.Delete(key)
        }

        ; Remove from simultaneous presses
        g_SimultaneousPresses.Delete(key)

        ; Release chord notes, unless held
        if (g_PlayingChords.Has(key)) {
            if (g_AutoHoldState == "on" && (g_AutoHoldMode == "chord" || g_AutoHoldMode == "all")) {
                ; Held: Do not release.
            } else {
                for index, note in g_PlayingChords[key] {
                    NoteOff(note)
                }
                g_PlayingChords.Delete(key)
            }
        }
    }
}

HandleChordExtension(key, config, isKeyDown) {
    ; 'z - x': action: 'chordExtension', param: ['M7']
    ; This is highly context-dependent (must be fired while a 'base' chord is held).
    ; For this initial release, we'll implement a simplified version that adds notes to the latest held chord.
    global g_PlayingChords, g_HeldChords, g_GlobalTranspose, g_ChordTranspose, g_Intervals

    ; Identify the base key (e.g., 'z' from 'z - x')
    parts := StrSplit(key, " - ")
    baseKey := parts[1]

    if (isKeyDown) {
        if (g_PlayingChords.Has(baseKey) || g_HeldChords.Has("CHORD")) {
            semitones := IntervalsToSemitones(config["param"])

            ; Get the root note of the base chord (simplified: first note of the playing chord)
            playingNotes := g_PlayingChords.Has(baseKey) ? g_PlayingChords[baseKey] : g_HeldChords["CHORD"]

            ; Assume the root is the lowest note of the existing chord
            rootNote := 127 ; Start high
            for index, note in playingNotes {
                if (note < rootNote) {
                    rootNote := note
                }
            }

            extensionNotes := []
            for index, semitone in semitones {
                newNote := rootNote + semitone + 12 ; Play extension notes an octave higher for good voicings
                extensionNotes.Push(newNote)
                NoteOn(newNote)
            }

            ; Store the extension notes so they can be released
            g_PlayingChords[key] := extensionNotes
        }
    } else {
        if (g_PlayingChords.Has(key)) {
            for index, note in g_PlayingChords[key] {
                NoteOff(note)
            }
            g_PlayingChords.Delete(key)
        }
    }
}

; --- Control Action Handlers (simplified, no need for isKeyDown) ---

HandleSetVoicing(key, config) {
    global g_CurrentVoicing
    g_CurrentVoicing := config["param"]
    MsgBox("Global Voicing Set: " StrSplit(g_CurrentVoicing, ", ").Join(", "))
}

HandleMemorizeVoicing(key, config) {
    global g_MemorizeVoicing, g_MemorizedVoicings
    if (config["param"] == "cycle") {
        g_MemorizeVoicing := (g_MemorizeVoicing == "on") ? "off" : "on"
    } else {
        g_MemorizeVoicing := config["param"]
    }
    MsgBox("Voicing Memorization: " g_MemorizeVoicing)
}

HandleClearMemorizedVoicing(key, config) {
    global g_MemorizedVoicings
    g_MemorizedVoicings := Map()
    MsgBox("All Memorized Voicings Cleared.")
}

HandleSetTranspose(key, config) {
    global g_GlobalTranspose
    val := config["param"]
    if (SubStr(val, 1, 1) == "+") {
        g_GlobalTranspose += SubStr(val, 2)
    } else if (SubStr(val, 1, 1) == "-") {
        g_GlobalTranspose -= SubStr(val, 2)
    } else {
        g_GlobalTranspose := val
    }
    g_GlobalTranspose := Mod(g_GlobalTranspose, 12)
    MsgBox("Global Transpose: " g_GlobalTranspose)
}

HandleSetChordTranspose(key, config) {
    global g_ChordTranspose
    val := config["param"]
    if (SubStr(val, 1, 1) == "+") {
        g_ChordTranspose += SubStr(val, 2)
    } else if (SubStr(val, 1, 1) == "-") {
        g_ChordTranspose -= SubStr(val, 2)
    } else {
        g_ChordTranspose := val
    }
    g_ChordTranspose := Mod(g_ChordTranspose, 12)
    MsgBox("Chord Transpose: " g_ChordTranspose)
}

HandleSetAutoHold(key, config) {
    global g_AutoHoldState, g_HeldChords
    if (config["param"] == "cycle") {
        g_AutoHoldState := (g_AutoHoldState == "on") ? "off" : "on"
    } else {
        g_AutoHoldState := config["param"]
    }
    if (g_AutoHoldState == "off") {
        for key, notes in g_HeldChords {
            for index, note in notes {
                NoteOff(note)
            }
        }
        g_HeldChords := Map()
    }
    MsgBox("Auto Hold: " g_AutoHoldState)
}

HandleSetAutoHoldMode(key, config) {
    global g_AutoHoldMode
    if (config["param"] == "cycle") {
        modeOrder := ["chord", "melody", "all"]
        idx := modeOrder.Find(g_AutoHoldMode)
        g_AutoHoldMode := modeOrder[Mod(idx, modeOrder.Length) + 1]
    } else {
        g_AutoHoldMode := config["param"]
    }
    MsgBox("Auto Hold Mode: " g_AutoHoldMode)
}

; ==================================================================================================
; == Hotkey Registration & Engine Loop
; ==================================================================================================

; --- Hotkey Callbacks ---

ChordEngine_KeyDown(hka) {
    global g_Config, g_SimultaneousPresses
    key := hka.Hotkey
    config := g_Config[key]
    action := config["action"]

    ; --- Simultaneous Press Tracking ---
    g_SimultaneousPresses[hka.KeyName] := A_TickCount

    ; --- Action Execution ---
    if (action == "note") {
        HandleNoteAction(hka.KeyName, config, true)
    } else if (action == "chord") {
        HandleChordAction(hka.KeyName, config, true)
    } else if (action == "chordExtension") {
        HandleChordExtension(key, config, true)
    } else { ; Control Actions (do not need KeyUp, just fire immediately)
        if (action == "setVoicing") {
            HandleSetVoicing(key, config)
        } else if (action == "memorizeVoicing") {
            HandleMemorizeVoicing(key, config)
        } else if (action == "clearMemorizedVoicing") {
            HandleClearMemorizedVoicing(key, config)
        } else if (action == "setTranspose") {
            HandleSetTranspose(key, config)
        } else if (action == "setChordTranspose") {
            HandleSetChordTranspose(key, config)
        } else if (action == "setAutoHold") {
            HandleSetAutoHold(key, config)
        } else if (action == "setAutoHoldMode") {
            HandleSetAutoHoldMode(key, config)
        }
    }
}

ChordEngine_KeyUp(hka) {
    global g_Config, g_SimultaneousPresses

    keyName := hka.KeyName ; The actual key released (e.g., 'q', 'z')

    ; Remove from simultaneous presses
    g_SimultaneousPresses.Delete(keyName)

    ; Find potential hotkeys that use this key as a BASE or SIMPLE key
    if (g_Config.Has(keyName)) {
        config := g_Config[keyName]
        action := config["action"]
        if (action == "note") {
            HandleNoteAction(keyName, config, false)
        } else if (action == "chord") {
            HandleChordAction(keyName, config, false)
        }
    }

    ; Handle release of chordExtension/followup notes (e.g., 'z - x' released when 'x' is up)
    ; This requires iterating through config["to"] find any 'base - modifier' hotkeys
    for hotkeyString, config in g_Config {
        if (InStr(hotkeyString, " - ") && InStr(hotkeyString, keyName)) {
            parts := StrSplit(hotkeyString, " - ")
            baseKey := parts[1]
            modifierKey := parts[2]

            if (modifierKey == keyName && config["action"] == "chordExtension") {
                HandleChordExtension(hotkeyString, config, false)
            }
        }
    }
}

; --- Register Hotkeys ---
for key, config in g_Config {
    ; Down event
    Hotkey key, ChordEngine_KeyDown
    ; Up event is only needed for keys that trigger sounds (note, chord, chordExtension)
    if (config["action"] == "note" || config["action"] == "chord") {
        ; Use the base key for the Up event to catch the release
        parts := StrSplit(key, [" & ", " - "])
        baseKey := parts[1]

        ; Only register Key Up once per base key. The 'T' option makes it a toggle/standard hotkey.
        ; The key name in the callback will be the actual key name (e.g. 'z'), not 'z & x'
        Hotkey baseKey " Up", ChordEngine_KeyUp
    }
    else if (config["action"] == "chordExtension") {
        ; Register Key Up for the follow-up key (e.g., 'x' for 'z - x')
        parts := StrSplit(key, " - ")
        modifierKey := parts[2]
        Hotkey modifierKey " Up", ChordEngine_KeyUp
    }
}

; --- System Controls (Not in the g_Config map but defined in the original example) ---
Hotkey "Esc", Panic, "T"
Hotkey "Up", (*) => HandleSetTranspose("", Map("action", "setTranspose", "param", "+1")), "T"
Hotkey "Down", (*) => HandleSetTranspose("", Map("action", "setTranspose", "param", "-1")), "T"
Hotkey "Right", (*) => HandleSetChordTranspose("", Map("action", "setChordTranspose", "param", "+1")), "T"
Hotkey "Left", (*) => HandleSetChordTranspose("", Map("action", "setChordTranspose", "param", "-1")), "T"

MsgBox("AHK MIDI Instrument Loaded. All features from config are enabled.")

; ==================================================================================================
; == SetTimeout/ClearTimeout Wrappers for AHKv2
; ==================================================================================================

; Map to store unique names for timers to allow clearing by reference.
global g_TimerMap := Map()
global g_TimerID := 0

; SetTimeout wrapper function
SetTimeout(Callback, Delay, Args*) {
    global g_TimerMap, g_TimerID

    ; 1. Generate a unique name for the timer (required by SetTimer if a function is passed)
    g_TimerID++
    timerName := "SetTimeout_" g_TimerID

    ; 2. Create a wrapper function that calls the original Callback and then disables itself.
    WrapperFunc := Func().Bind(timerName, Callback, Args*)

    ; 3. Store the timer name/reference and set the timer.
    ; SetTimer: Time must be positive (ms). Recurrence must be 0 (one-shot).
    SetTimer(WrapperFunc, Delay)

    ; 4. Store the unique timer name/reference for later clearing.
    g_TimerMap[timerName] := WrapperFunc

    return timerName
}

; Function executed by SetTimer to run the callback and disable itself.
TimeoutWrapper(TimerName, Callback, Args*) {
    global g_TimerMap

    ; 1. Execute the original callback with its arguments.
    Callback.Call(Args*)

    ; 2. Immediately disable the timer (SetTimer(Func, 0))
    SetTimer(g_TimerMap[TimerName], 0)

    ; 3. Remove from the map
    g_TimerMap.Delete(TimerName)
}

; ClearTimeout wrapper function
ClearTimeout(TimerName) {
    global g_TimerMap

    if (g_TimerMap.Has(TimerName)) {
        ; Disable the timer using the stored function reference
        SetTimer(g_TimerMap[TimerName], 0)

        ; Remove from the map
        g_TimerMap.Delete(TimerName)
        return true
    }
    return false
}
