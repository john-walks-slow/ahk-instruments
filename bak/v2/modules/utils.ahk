; ==================================================================================================
; == Utilities
; ==================================================================================================

; Joins the elements of an array with a string separator.
StrJoin(arr, sep) {
    out := ""
    for i, el in arr {
        out .= (i > 1 ? sep : "") . el
    }
    return out
}
