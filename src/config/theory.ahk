; ==================================================================================================
; == 音阶与和弦公式 (Scale & Chord Formulas)
; ==================================================================================================
global MAJOR_SCALE := [0, 2, 4, 5, 7, 9, 11] ; Intervals from root

global CHORD_FORMULAS := Map(
    "Maj", [0, 4, 7], "min", [0, 3, 7], "dim", [0, 3, 6]
)

global EXTENSION_INTERVALS := Map(
    "Major", Map(7, 11, 9, 14, 11, 17), ; Maj7, 9, 11
    "Minor", Map(7, 10, 9, 14, 11, 17), ; min7, 9, 11
    "Dominant", Map(7, 10, 9, 14, 11, 17), ; Dom7, 9, 11
    "Diminished", Map(7, 9)                ; dim7 (bb7)
)