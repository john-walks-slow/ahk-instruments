#SingleInstance force
#Include <MIDIv2>

; ==================================================================================================
; == 全局开关 (Global Toggle)
; ==================================================================================================
IsEnabled(*) {
    global
    ; ScrollLock is the global MIDI switch (Toggle state)
    return GetKeyState("ScrollLock", "T")
}
HotIf(IsEnabled)

; ==================================================================================================
; == 配置 (Configuration)
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

; ==================================================================================================
; == 全局状态变量 (Global State)
; ==================================================================================================
; Transposition Offsets
global g_CurrentKey := 60, g_CurrentOctave := 0  ; Base melody key (MIDI Note 60 = C4) and octave shift
global g_ChordTransposeKey := 0, g_ChordTransposeOctave := 0 ; Chord-only key/octave offset
; Chord State
global g_HeldChordKeys := [], g_ChordBaseKey := ""           ; Keys currently held down for chord recognition
global g_SoundingChordNotes := []                            ; MIDI notes currently ON from the chord function
global g_HeldChord_by_Capslock := []                         ; Notes latched by CapsLock
global g_IsChordLatchOn := false                             ; CapsLock state
global g_ActiveVoicingKey := "Numpad0"                       ; Key of the currently selected voicing preset
; Note Tracking
global g_SoundingNotes := Map()                              ; Map<MIDI_Note, Count> for polyphony and note-off
global g_MelodyKeysDown := Map()                             ; Map<Key, MIDI_Note> for melody key tracking

; ==================================================================================================
; == 音阶与和弦公式 (Scale & Chord Formulas)
; ==================================================================================================
global MAJOR_SCALE := [0, 2, 4, 5, 7, 9, 11] ; Intervals from root
global CHORD_FORMULAS := Map( ; Intervals from root (e.g., [0, 4, 7] = R, M3, P5)
    "Maj", [0, 4, 7], "min", [0, 3, 7], "dim", [0, 3, 6],
    "Maj7", [0, 4, 7, 11], "min7", [0, 3, 7, 10], "Dom7", [0, 4, 7, 10], "dim7", [0, 3, 6, 9],
    "Maj9", [0, 4, 7, 11, 14], "min9", [0, 3, 7, 10, 14], "Dom9", [0, 4, 7, 10, 14],
    "Maj11", [0, 4, 7, 11, 14, 17], "min11", [0, 3, 7, 10, 14, 17], "Dom11", [0, 4, 7, 10, 14, 17]
)

; ==================================================================================================
; == [优化后] 可定制的声部配置预设 (Optimized Voicing Presets)
; ==================================================================================================
; 定义声部配置，指定使用哪个和弦音（Tone）及其相对的八度（OCTAVE）偏移。
; 结构: Map(VoicingKey, Map(NumNotes, [[ToneIndex, OctaveShift], ...]))
; ToneIndex: 1=根音, 2=三音, 3=五音, 4=七音, 5=九音, etc.
; OctaveShift: 0=同八度, 1=高八度, -1=低八度.
global VOICING_PRESETS := Map(
    "Numpad0", Map( ; 根位和弦 (Root Position) - 默认
        3, [[1, 0], [2, 0], [3, 0]], ; R-3-5
        4, [[1, 0], [2, 0], [3, 0], [4, 0]], ; R-3-5-7
        5, [[1, 0], [2, 0], [3, 0], [4, 0], [5, 0]] ; R-3-5-7-9
    ),
    "Numpad1", Map( ; 第一转位 (1st Inversion)
        3, [[2, 0], [3, 0], [1, 1]], ; 3-5-R
        4, [[2, 0], [3, 0], [4, 0], [1, 1]] ; 3-5-7-R
    ),
    "Numpad2", Map( ; 第二转位 (2nd Inversion)
        3, [[3, 0], [1, 1], [2, 1]], ; 5-R-3
        4, [[3, 0], [4, 0], [1, 1], [2, 1]] ; 5-7-R-3
    ),
    "Numpad3", Map( ; 第三转位 (3rd Inversion) - 仅适用于七和弦及以上
        4, [[4, 0], [1, 1], [2, 1], [3, 1]] ; 7-R-3-5
    ),
    "Numpad4", Map( ; Drop 2 声部 - 将顶部第二音降低八度，常用于吉他和键盘
        4, [[3, -1], [1, 0], [2, 0], [4, 0]] ; 由 R-3-5-7 变为 5(低)-R-3-7
    ),
    "Numpad5", Map( ; 开放/扩展声部 (Spread/Open Voicing)
        3, [[1, 0], [3, 0], [2, 1]], ; R-5-3(高)
        4, [[1, 0], [4, 0], [2, 1], [3, 1]] ; R-7-3(高)-5(高)
    ),
    "Numpad6", Map( ; 现代键盘风格 (Contemporary Keyboard Style)
        3, [[1, -1], [2, 0], [3, 0]], ; R(低)-3-5
        4, [[1, -1], [3, 0], [4, 0], [2, 1]] ; R(低)-5-7-3(高)
    ),
    "Media_Play_Pause", Map( ; 加倍根音 (Doubled Root) - 声音更饱满
        3, [[1, -1], [1, 0], [2, 0], [3, 0]],
        4, [[1, -1], [1, 0], [2, 0], [3, 0], [4, 0]]
    ),
    "Media_Next", Map( ; 低音根音 + 高位和弦 (Low Root + High Cluster)
        4, [[1, -1], [3, 0], [4, 0], [5, 0]], ; R(低) + 5-7-9
        5, [[1, -1], [3, 0], [4, 0], [5, 0], [6, 0]] ; R(低) + 5-7-9-11
    ),
    "Media_Prev", Map( ; 无根音和弦 (Rootless Voicing) - 左手常用
        4, [[2, 0], [3, 0], [4, 0], [5, 0]], ; 3-5-7-9 (适用于九和弦)
        5, [[2, 0], [4, 0], [5, 0], [6, 0]]  ; 3-7-9-11 (适用于十一和弦)
    )
)

global KEY_TO_CHORD := Map(
    "z", Map("Root", 1, "Quality", "Maj", "Modifiers", Map("x", "Maj7", "c", "Maj9", "v", "Maj11")), ; I
    "a", Map("Root", 1, "Quality", "min", "Modifiers", Map("d", "min7", "f", "min9", "g", "min11")), ; i
    "x", Map("Root", 2, "Quality", "min", "Modifiers", Map("c", "min7", "v", "min9", "b", "min11")), ; ii
    "s", Map("Root", 2, "Quality", "Maj", "Modifiers", Map("f", "Dom7", "g", "Dom9", "h", "Dom11")), ; II -> V/V
    "c", Map("Root", 3, "Quality", "min", "Modifiers", Map("v", "min7", "b", "min9", "n", "min11")), ; iii
    "d", Map("Root", 3, "Quality", "Maj", "Modifiers", Map("g", "Maj7", "h", "Maj9", "j", "Maj11")), ; III
    "v", Map("Root", 4, "Quality", "Maj", "Modifiers", Map("b", "Maj7", "n", "Maj9", "m", "Maj11")), ; IV
    "f", Map("Root", 4, "Quality", "min", "Modifiers", Map("h", "min7", "j", "min9", "k", "min11")), ; iv
    "b", Map("Root", 5, "Quality", "Maj", "Modifiers", Map("n", "Dom7", "m", "Dom9", ",", "Dom11")), ; V
    "g", Map("Root", 5, "Quality", "min", "Modifiers", Map("j", "min7", "k", "min9", "l", "min11")), ; v
    "n", Map("Root", 6, "Quality", "min", "Modifiers", Map("m", "min7", ",", "min9", ".", "min11"), "OctaveShift", -1), ; vi
    "LShift", Map("Root", 6, "Quality", "min", "Modifiers", Map("m", "min7", ",", "min9", ".", "min11"), "OctaveShift", -
    1), ; vi (LShift only)
    "h", Map("Root", 6, "Quality", "Maj", "Modifiers", Map("k", "Maj7", "l", "Maj9", ";", "Maj11")), ; VI
    "m", Map("Root", 7, "Quality", "dim", "Modifiers", Map(",", "dim7")), ; vii°
    "j", Map("Root", 7, "Quality", "Maj", "Modifiers", Map("l", "Maj7"))  ; VII
)

; ==================================================================================================
; == 核心MIDI与工具函数 (Core MIDI & Utility Functions)
; ==================================================================================================

; Utility to convert MIDI note number to a common name (e.g., 60 -> C4)
GetNoteName(midiNote) {
    noteNames := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    noteIndex := Mod(midiNote, 12) + 1
    octave := Floor(midiNote / 12) - 1
    return noteNames[noteIndex] . octave
}

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
    g_SoundingNotes.Clear(), g_SoundingChordNotes := []
    g_HeldChord_by_Capslock := [], g_MelodyKeysDown.Clear()
    g_IsChordLatchOn := false
}

Cleanup(*) {
    global
    Panic()
}

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

        ; If the pressed key is a voicing preset, update the active voicing state.
        if VOICING_PRESETS.Has(key) {
            g_ActiveVoicingKey := key
            UpdateChord() ; Re-render the chord with new voicing
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
    targetNotes := BuildChordFromHeldKeys()
    notesToStop := [], notesToPlay := []

    ; Determine which old notes to stop
    for oldNote in g_SoundingChordNotes {
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
        for oldNote in g_SoundingChordNotes
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

    g_SoundingChordNotes := targetNotes
}

; Calculates the final chord notes based on global state and held keys
BuildChordFromHeldKeys() {
    global
    if (g_ChordBaseKey = "" || !KEY_TO_CHORD.Has(g_ChordBaseKey))
        return []

    chordDef := KEY_TO_CHORD.get(g_ChordBaseKey)
    scaleDegree := chordDef.get("Root")
    finalQuality := chordDef.get("Quality")
    octaveShift := chordDef.Has("OctaveShift") ? chordDef.get("OctaveShift") : 0

    ; Check for chord modifiers (e.g., Maj7, min9)
    if chordDef.Has("Modifiers") {
        ; Iterate held keys in reverse to prioritize later presses as modifiers
        loop g_HeldChordKeys.Length {
            modifierKey := g_HeldChordKeys[g_HeldChordKeys.Length - A_Index + 1]
            if chordDef.get("Modifiers").Has(modifierKey) {
                finalQuality := chordDef.get("Modifiers").get(modifierKey)
                break
            }
        }
    }

    ; Calculate the root note in MIDI number
    baseOctave := g_CurrentOctave + g_ChordTransposeOctave + octaveShift
    rootNote := g_CurrentKey + g_ChordTransposeKey + MAJOR_SCALE[scaleDegree] + (baseOctave * 12)

    ; Build the "root" chord (all tones from formula, starting at rootNote)
    rootChord := []
    if CHORD_FORMULAS.Has(finalQuality)
        for interval in CHORD_FORMULAS.get(finalQuality)
            rootChord.Push(rootNote + interval)
    if rootChord.Length = 0
        return []

    ; Apply the active voicing preset
    voicingKey := g_ActiveVoicingKey
    voicingPresetMap := VOICING_PRESETS.get(voicingKey)
    numNotes := rootChord.Length

    if voicingPresetMap.Has(numNotes) {
        presetArray := voicingPresetMap.get(numNotes)
        return ApplyExtendedVoicing(rootChord, presetArray)
    }

    return rootChord
}

; Applies the voicing rules (ToneIndex and OctaveShift) to the root chord
; rootChord: [Note_Root, Note_3rd, Note_5th, ...]
; preset: [[ToneIndex, OctaveShift], ...]
ApplyExtendedVoicing(rootChord, preset) {
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

; Simple Bubble Sort for chord notes (needed to ensure consistent voice leading)
SortVoicedChord(arr) {
    global
    loop arr.Length - 1 {
        loop arr.Length - A_Index {
            j := A_Index + 1
            if (arr[A_Index] > arr[j]) {
                temp := arr[A_Index]
                arr[A_Index] := arr[j]
                arr[j] := temp
            }
        }
    }
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

; ==================================================================================================
; == 旋律键盘 (Melody Keyboard)
; ==================================================================================================
global MELODY_MAP := Map(
    "Tab", -12, "q", -10, "w", -8, "e", -7, "r", -5, "t", -3, "y", -1,
    "1", -11, "2", -9, "4", -6, "5", -4, "6", -2,
    "u", 0, "i", 2, "o", 4, "p", 5, "[", 7, "]", 9, "\", 11,
    "8", 1, "9", 3, "-", 6, "=", 8, "Backspace", 10,
    "Delete", 12, "End", 14, "PgDn", 16, "Numpad7", 17, "Numpad8", 19, "Numpad9", 21, "NumpadAdd", 23,
    "Insert", 13, "Home", 15, "NumLock", 18, "NumpadDiv", 20, "NumpadMult", 22, "NumpadSub", 24
)

; Handles key down/up events for melody keys
HandleMelodyKey(key, state, *) {
    global
    if !MELODY_MAP.Has(key)
        return
    interval := MELODY_MAP.get(key)
    noteToPlay := g_CurrentKey + interval + (g_CurrentOctave * 12)

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

; ==================================================================================================
; == 系统控制与转调 (System Controls & Transposition)
; ==================================================================================================

HandleEsc(*) {
    global
    Panic()
    MsgBox "Emergency Stop! All notes have been turned off."
}

; Adjusts the global transpose state (affects both melody and chord root)
HandleTranspose(keyDelta, octaveDelta, *) {
    global
    g_CurrentKey += keyDelta
    g_CurrentOctave += octaveDelta

    ; --- [UPDATE 1] Show tooltip of current key and offset ---
    currentRootNote := g_CurrentKey + (g_CurrentOctave * 12)
    tooltipText := "Global Root: " GetNoteName(currentRootNote)
    . "`nChord Offset: " GetNoteName(60 + g_ChordTransposeKey) . " (" g_ChordTransposeKey . " semi)"
    Tooltip tooltipText, , , 1
    SetTimer () => Tooltip(, , , 1), -2000 ; Hide after 2 seconds

    UpdateChord() ; Update chord to reflect the new transpose
}

; Adjusts the chord-only transpose state (affects only the chord root)
HandleChordTranspose(keyDelta, octaveDelta, *) {
    global
    g_ChordTransposeKey += keyDelta
    g_ChordTransposeOctave += octaveDelta

    ; --- [UPDATE 1] Show tooltip of current key and offset ---
    currentChordOffset := g_ChordTransposeKey + (g_ChordTransposeOctave * 12)
    tooltipText := "Global Root: " GetNoteName(g_CurrentKey + (g_CurrentOctave * 12))
    . "`nChord Offset: " GetNoteName(60 + currentChordOffset) . " (" currentChordOffset . " semi)"
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

; Global Transpose Hotkeys (Melody and Chord Base)
Hotkey "Up", HandleTranspose.Bind(1, 0)      ; Up arrow: +1 Semitone
Hotkey "Down", HandleTranspose.Bind(-1, 0)   ; Down arrow: -1 Semitone
Hotkey "Right", HandleTranspose.Bind(0, 1)   ; Right arrow: +1 Octave (12 semitones)
Hotkey "Left", HandleTranspose.Bind(0, -1)    ; Left arrow: -1 Octave (-12 semitones)

; Chord-Only Transpose Hotkeys (Right Shift + Arrows)
Hotkey ">+Up", HandleChordTranspose.Bind(1, 0)      ; RShift+Up: +1 Semitone (Chord Only)
Hotkey ">+Down", HandleChordTranspose.Bind(-1, 0)   ; RShift+Down: -1 Semitone (Chord Only)
Hotkey ">+Right", HandleChordTranspose.Bind(0, 1)   ; RShift+Right: +1 Octave (Chord Only)
Hotkey ">+Left", HandleChordTranspose.Bind(0, -1)    ; RShift+Left: -1 Octave (Chord Only)

HotIf()