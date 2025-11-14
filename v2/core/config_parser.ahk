; ==================================================================================================
; == Configuration Parser
; ==================================================================================================
LoadConfig() {
    global
    try {
        OutputDebug("Loading config.json5...")
        configPath := A_ScriptDir . "\config.json5"
        json5Str := FileRead(configPath)
        g_Config := jsongo.Parse(json5Str)

        OutputDebug("config.json5 parsed successfully.")

        ; Extract system settings before processing hotkeys
        ; if (g_Config.Has("combinationDelay")) {
        ;     g_CombinationDelay := g_Config.Get("combinationDelay")
        ;     g_Config.Delete("combinationDelay")
        ;     OutputDebug("Set combinationDelay to: " g_CombinationDelay)
        ; }

        ProcessConfig()
    } catch as e {
        MsgBox "Error loading or parsing config.json5:`n" e.Message
        OutputDebug("Error loading config: " e.Message ". Exiting.")
        ExitApp
    }
}

; Processes the raw config, expanding modifiers and creating a flat hotkey map.
ProcessConfig() {
    global
    g_Hotkeys := Map()

    for hotkeyStr, definition in g_Config {
        ; Store the base definition
        AddHotkeyDefinition(hotkeyStr, definition)

        ; Expand short-syntax modifiers
        if (definition.Has("param") && Type(definition.param) = "Map" && definition.param.Has("modifiers")) {
            baseDef := definition.Clone()
            baseParam := baseDef.param
            modifiers := baseParam.Delete("modifiers")

            for modKey, modValue in modifiers {
                ; Create a new definition for the combination
                modDef := baseDef.Clone()
                modDef.param := baseParam.Clone()

                ; Apply the modifier. It can be a simple string to override the 'shape'
                ; or a map of parameters to merge.
                if (Type(modValue) = "String") {
                    ; Split comma-separated string into an array for the shape, trimming whitespace
                    shapeArr := []
                    for _, val in StrSplit(modValue, ",")
                        shapeArr.Push(Trim(val))
                    modDef.param.Set("shape", shapeArr)
                } else if (Type(modValue) = "Map") {
                    ; Merge the map of changes from the modifier
                    for key, value in modValue {
                        modDef.param.Set(key, value)
                    }
                }

                ; Build the combination string. The modKey can be a single key "X"
                ; or a comma-separated list for a multi-key modifier "X,C".
                comboStr := hotkeyStr
                modKeyParts := StrSplit(modKey, ",")
                for _, part in modKeyParts {
                    comboStr .= " & " . Trim(part)
                }
                AddHotkeyDefinition(comboStr, modDef)
            }
        }
    }
}

; Adds a definition to the global g_Hotkeys map, using a sorted, normalized key.
AddHotkeyDefinition(hotkeyStr, definition) {
    global
    keys := StrSplit(hotkeyStr, "&")
    cleanedKeys := []
    for _, key in keys {
        cleanedKeys.Push(Trim(key))
    }
    ; cleanedKeys.Sort()

    normalizedKey := ""
    for i, key in cleanedKeys {
        normalizedKey .= key . (i < cleanedKeys.Length ? " " : "")
    }

    g_Hotkeys.Set(normalizedKey, definition)
}
