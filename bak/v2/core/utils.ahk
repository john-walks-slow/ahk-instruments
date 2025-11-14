; ==================================================================================================
; == Utilities
; ==================================================================================================
global INTERVAL_SEMITONES := Map(
    "P1", 0, "m2", 1, "M2", 2, "m3", 3, "M3", 4, "P4", 5, "A4", 6, "d5", 6, "P5", 7,
    "m6", 8, "M6", 9, "m7", 10, "M7", 11, "P8", 12, "m9", 13, "M9", 14, "P11", 17, "P13", 21
)
global NOTE_NAMES := Map("C", 0, "D", 2, "E", 4, "F", 5, "G", 7, "A", 9, "B", 11)

; Parses a note string like "C#4" into a MIDI number.
ParseNote(noteStr) {
    global
    if RegExMatch(noteStr, "i)^([A-G])([#b]?)(-?\d)$", &m) {
        noteName := m[1]
        accidental := m[2]
        octave := m[3]

        noteVal := NOTE_NAMES.Get(noteName)
        if (accidental = "#")
            noteVal++
        else if (accidental = "b")
            noteVal--

        return noteVal + (octave + 1) * 12
    } else if (IsNumber(noteStr)) {
        return Integer(noteStr)
    }
    return 60 ; Default to C4 on error
}

; Parses an array of interval strings (e.g., ["P1", "M3", "P5"]) into an array of semitone offsets.
ParseIntervals(shape) {
    global
    semitones := []
    for _, intervalStr in shape {
        if (INTERVAL_SEMITONES.Has(intervalStr)) {
            semitones.Push(INTERVAL_SEMITONES.Get(intervalStr))
        }
    }
    return semitones
}

; Simple numeric sort for arrays.
SortArray(arr) {
    ; arr.Sort("N")
}
