#include utils.ahk

; ==================================================================================================
; == Input Handler
; ==================================================================================================

; Registers all unique keys found in the config to trigger our central handlers.
RegisterHotkeys() {
    global
    uniqueKeys := Map()
    for comboKey, _ in g_Hotkeys {
        keys := StrSplit(comboKey, " ")
        for _, key in keys {
            uniqueKeys.Set(key, true)
        }
    }

    for key in uniqueKeys {
        try {
            Hotkey key, OnKeyDown.Bind(key)
            Hotkey key " Up", OnKeyUp.Bind(key)
        } catch as e {
            MsgBox "Failed to register hotkey: " key ".`nThis key may be reserved by the system or another application."
        }
    }
}

; Central handler for all key down events.
OnKeyDown(key) {
    global
    if (!g_IsEnabled)
        return
    if (g_HeldKeys.Has(key)) ; Ignore key repeats
        return

    g_HeldKeys.Set(key, true)

    ; --- NEW Followup Logic ---
    ; If a chord is active, check if the new key is a followup.
    if (g_CurrentChordDef != "" && g_CurrentChordDef.Has("followups")) {
        followups := g_CurrentChordDef.followups
        if (followups.Has(key)) {
            param := followups.Get(key)
            ; The param can be a single interval string or an array of them.
            if (Type(param) = "String") {
                param := [param]
            }
            DispatchAction(Map("action", "chordExtension", "param", param), "down", key, "")
            return ; This key was a followup, do not process as a new combination
        }
    }

    ; Always cancel any pending timer, as the state of held keys is changing.
    if IsObject(g_InputTimer)
        SetTimer(g_InputTimer, 0)

    ; If the currently held keys could form part of a larger combination,
    ; we wait for a short delay (for modifiers). Otherwise, we process immediately.
    if (IsPotentialCombination()) {
        g_InputTimer := SetTimer(ProcessCombination, -g_CombinationDelay)
    } else {
        ProcessCombination()
    }
}

; Checks if the currently held keys are a subset of any larger defined combination.
IsPotentialCombination() {
    global
    currentKeyCount := g_HeldKeys.Count
    if (currentKeyCount = 0)
        return false

    ; Create a temporary array of held keys for checking
    currentKeys := []
    for key in g_HeldKeys
        currentKeys.Push(key)

    for comboKeyStr in g_Hotkeys {
        definedKeys := StrSplit(comboKeyStr, " ")
        if (definedKeys.Length > currentKeyCount) {
            isSuperset := true
            for _, heldKey in currentKeys {
                ; Check if heldKey is present in definedKeys
                found := false
                for _, definedKey in definedKeys {
                    if (heldKey = definedKey) {
                        found := true
                        break
                    }
                }
                if !found {
                    isSuperset := false
                    break
                }
            }
            if (isSuperset)
                return true ; Found a potential larger combination
        }
    }
    return false
}

; Processes the currently held keys after a short delay (or immediately).
ProcessCombination() {
    global
    activeComboKey := GetActiveCombination()
    if (g_Hotkeys.Has(activeComboKey)) {
        definition := g_Hotkeys.Get(activeComboKey)
        DispatchAction(definition, "down", "", activeComboKey)
    }
}

; Central handler for all key up events.
OnKeyUp(key) {
    global
    if (!g_IsEnabled)
        return

    ; --- NEW Followup Release Logic ---
    if (g_ChordExtensionNotes.Has(key)) {
        DispatchAction(Map("action", "chordExtension"), "up", key, "")
    }

    ; The combination that was active *before* this key was released.
    activeComboKeyBeforeRelease := GetActiveCombination()

    ; Release the key from our state tracker.
    g_HeldKeys.Delete(key)

    ; If the released key was part of the active base chord, stop the chord entirely.
    if (g_CurrentChordDef != "" && InStr(g_ActiveChordHotkey, key)) {
        StopChord()
        ; Cancel any pending combination processing from other keys.
        if IsObject(g_InputTimer)
            SetTimer(g_InputTimer, 0)
    }

    ; Dispatch the "up" action for the combination that just ended.
    ; This is primarily for single-key "note" actions to stop the note.
    if (g_Hotkeys.Has(activeComboKeyBeforeRelease)) {
        definition := g_Hotkeys.Get(activeComboKeyBeforeRelease)
        DispatchAction(definition, "up", key, activeComboKeyBeforeRelease)
    }
}

; Builds a normalized combination string from the currently held keys.
GetActiveCombination() {
    global
    activeKeys := []
    for key in g_HeldKeys {
        activeKeys.Push(key)
    }
    ; activeKeys.Sort()
    return StrJoin(activeKeys, " ")
}

; Calls the appropriate action function based on the hotkey definition.
DispatchAction(definition, state, triggerKey, hotkey) {
    global
    action := definition.action
    param := definition.Has("param") ? definition.param : ""

    ; Add the original hotkey string to the definition for context
    definition.hotkey := hotkey

    switch action {
        case "note": Action_Note(param, state, triggerKey)
        case "chord": Action_Chord(param, state, definition)
        case "chordExtension": if (g_CurrentChordDef != "")
            Action_ChordExtension(param, state, triggerKey)
        case "setVoicing": if (state = "down")
            Action_SetVoicing(param, triggerKey)
        case "setTranspose": if (state = "down")
            Action_SetTranspose(param)
        case "setChordTranspose": if (state = "down")
            Action_SetChordTranspose(param)
        case "toggleArp": if (state = "down")
            Action_ToggleArp()
        case "setArpPattern": if (state = "down")
            Action_SetArpPattern(param, triggerKey)
        case "toggleLatch": if (state = "down")
            Action_ToggleLatch()
        case "panic": if (state = "down")
            Panic()
        case "toggleEnabled": if (state = "down")
            g_IsEnabled := !g_IsEnabled
    }
}
