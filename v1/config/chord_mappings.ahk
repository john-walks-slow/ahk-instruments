; "Quality": The base triad (from CHORD_FORMULAS).
; "Type": Determines the quality of extensions (from EXTENSION_INTERVALS).
; "Modifiers": Map("key", degree) -> "c" adds the 9th degree.
global KEY_TO_CHORD := Map(
    "z", Map("Root", 1, "Quality", "Maj", "Type", "Major", "Modifiers", Map("x", 7, "c", 9, "v", 11)), ; I
    "a", Map("Root", 1, "Quality", "min", "Type", "Minor", "Modifiers", Map("d", 7, "f", 9, "g", 11)), ; i
    "x", Map("Root", 2, "Quality", "min", "Type", "Minor", "Modifiers", Map("c", 7, "v", 9, "b", 11)), ; ii
    "s", Map("Root", 2, "Quality", "Maj", "Type", "Dominant", "Modifiers", Map("f", 7, "g", 9, "h", 11)), ; II -> V/V
    "c", Map("Root", 3, "Quality", "min", "Type", "Minor", "Modifiers", Map("v", 7, "b", 9, "n", 11)), ; iii
    "d", Map("Root", 3, "Quality", "Maj", "Type", "Major", "Modifiers", Map("g", 7, "h", 9, "j", 11)), ; III
    "v", Map("Root", 4, "Quality", "Maj", "Type", "Major", "Modifiers", Map("b", 7, "n", 9, "m", 11)), ; IV
    "f", Map("Root", 4, "Quality", "min", "Type", "Minor", "Modifiers", Map("h", 7, "j", 9, "k", 11)), ; iv
    "b", Map("Root", 5, "Quality", "Maj", "Type", "Dominant", "Modifiers", Map("n", 7, "m", 9, ",", 11)), ; V
    "g", Map("Root", 5, "Quality", "min", "Type", "Minor", "Modifiers", Map("j", 7, "k", 9, "l", 11)), ; v
    "n", Map("Root", 6, "Quality", "min", "Type", "Minor", "Modifiers", Map("m", 7, ",", 9, ".", 11), "OctaveShift", -1
    ), ; vi
    "h", Map("Root", 6, "Quality", "Maj", "Type", "Major", "Modifiers", Map("k", 7, "l", 9, ";", 11)), ; VI
    "m", Map("Root", 7, "Quality", "dim", "Type", "Diminished", "Modifiers", Map(",", 7)), ; vii°
    "j", Map("Root", 7, "Quality", "Maj", "Type", "Major", "Modifiers", Map("l", 7))  ; VII
)
; LShift is an alias for 'n' (vi chord)
KEY_TO_CHORD.Set("LShift", KEY_TO_CHORD.get("n"))