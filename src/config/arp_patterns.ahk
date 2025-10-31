; ==================================================================================================
; == 琶音器模式 (Arpeggiator Patterns)
; ==================================================================================================
; Patterns are arrays of indices. 1 = 1st note of chord, 2 = 2nd, etc.
; The pattern will loop and adapt to the number of notes in the current chord.
global ARP_PATTERNS := Map(
    "Numpad1", [1, 2, 3, 4, 5, 6, 7, 8],          ; Up
    "Numpad2", [8, 7, 6, 5, 4, 3, 2, 1],          ; Down
    "Numpad3", [1, 2, 3, 4, 3, 2],                ; Up & Down 1
    "Numpad4", [1, 3, 2, 4, 3, 5, 4, 6],          ; Up & Down 2
    "Numpad5", [1, 3, 5, 7, 2, 4, 6, 8],          ; By thirds
    "Numpad6", ""                                ; Random (handled as a special case)
)
; Also allow other Numpad keys to select patterns
ARP_PATTERNS.Set("Numpad7", ARP_PATTERNS.get("Numpad1"))
ARP_PATTERNS.Set("Numpad8", ARP_PATTERNS.get("Numpad3"))
ARP_PATTERNS.Set("Numpad9", ARP_PATTERNS.get("Numpad5"))