; ==================================================================================================
; == 可定制的声部配置预设 (Voicing Presets)
; ==================================================================================================
; 定义声部配置，指定使用哪个和弦音（Tone）及其相对的八度（OCTAVE）偏移。
; ToneIndex: 1=根音, 2=三音, 3=五音, 4=七音, 5=九音, etc.
; OctaveShift: 0=同八度, 1=高八度, -1=低八度.
; Supports two formats:
; 1. Map: Map(NumNotes, [[Tone, Oct], ...]) for specific voicings per chord size.
; 2. Array: [[Tone, Oct], ...] to apply one voicing rule to any chord size.
global VOICING_PRESETS := Map(
    "Numpad0", Map( ; 根位和弦 (Root Position) - 默认
        3, [[1, 0], [2, 0], [3, 0]],
        4, [[1, 0], [2, 0], [3, 0], [4, 0]],
        5, [[1, 0], [2, 0], [3, 0], [4, 0], [5, 0]],
        6, [[1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0]]
    ),
    "Numpad1", Map( ; 第一转位 (1st Inversion)
        3, [[2, 0], [3, 0], [1, 1]],
        4, [[2, 0], [3, 0], [4, 0], [1, 1]]
    ),
    "Numpad2", Map( ; 第二转位 (2nd Inversion)
        3, [[3, 0], [1, 1], [2, 1]],
        4, [[3, 0], [4, 0], [1, 1], [2, 1]]
    ),
    "Numpad3", Map( ; 第三转位 (3rd Inversion) - 仅适用于七和弦及以上
        4, [[4, 0], [1, 1], [2, 1], [3, 1]]
    ),
    "Numpad4", Map( ; Drop 2 声部 - 将顶部第二音降低八度
        4, [[3, -1], [1, 0], [2, 0], [4, 0]] ; 由 R-3-5-7 变为 5(低)-R-3-7
    ),
    "Numpad5", Map( ; 开放/扩展声部 (Spread/Open Voicing)
        3, [[1, 0], [3, 0], [2, 1]],
        4, [[1, 0], [4, 0], [2, 1], [3, 1]]
    ),
    "Numpad6", Map( ; 现代键盘风格 (Contemporary Keyboard Style)
        3, [[1, -1], [2, 0], [3, 0]],
        4, [[1, -1], [3, 0], [4, 0], [2, 1]]
    ),
    "Numpad7", [
        [1, -1], [3, 0], [5, 0], [2, 1], [4, 1] ; Low Root, Mid 5th/9th, High 3rd/7th. Works for any chord size.
    ],
    "Media_Play_Pause", Map( ; 加倍根音 (Doubled Root)
        3, [[1, -1], [1, 0], [2, 0], [3, 0]],
        4, [[1, -1], [1, 0], [2, 0], [3, 0], [4, 0]]
    ),
    "Media_Next", Map( ; 低音根音 + 高位和弦 (Low Root + High Cluster)
        4, [[1, -1], [2, 0], [3, 0], [4, 0]], ; R(低) + 5-7-9
        5, [[1, -1], [2, 0], [3, 0], [4, 0], [5, 0]] ; R(低) + 5-7-9-11
    ),
    "Media_Prev", Map( ; 无根音和弦 (Rootless Voicing)
        4, [[2, 0], [3, 0], [4, 0], [5, 0]], ; 3-5-7-9 (适用于九和弦)
        5, [[2, 0], [3, 0], [4, 0], [5, 0]]  ; 3-7-9-11 (适用于十一和弦) - Note: ToneIndex now maps to available notes
    )
)