; ==================================================================================================
; == 工具函数 (Utility Functions)
; ==================================================================================================

; Utility to convert MIDI note number to a common name (e.g., 60 -> C4)
GetNoteName(midiNote) {
    noteNames := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    noteIndex := Mod(midiNote, 12) + 1
    octave := Floor(midiNote / 12) - 1
    return noteNames[noteIndex] . octave
}

; Simple Bubble Sort for chord notes/intervals
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
