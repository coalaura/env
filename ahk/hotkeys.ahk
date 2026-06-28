#SingleInstance Force

; FiveM
GroupAdd "FiveM", "ahk_exe FiveM_GTAProcess.exe"

; Check if FiveM is focused
#HotIf WinActive("FiveM") || WinActive("Minecraft") || WinActive("Feather Client")

; ^ is FiveM push-to-talk
^::F7

#HotIf

; Check if FiveM is not focused
#HotIf !WinActive("FiveM") && !WinActive("Minecraft") && !WinActive("Feather Client")

; Remove double-press of ^ key
^::SendText("^")

#HotIf

; Remove double-press of ` key
`::SendText("``")
´::SendText("``")

; Right windows button locks screen
RWin::Send("#L")

; Ensure F7 is released when leaving FiveM
SetTimer CheckFocus, 200

; Release F7 if FiveM is not active
FiveMActive := false

CheckFocus()
{
    global FiveMActive

    if (WinActive("FiveM")) {
        FiveMActive := true
    } else if (FiveMActive && !GetKeyState("Alt", "P")) {
        FiveMActive := false

        SendEvent("{F7 up}")
    }
}

; Ctrl + Alt + Shift + F12 types 16 random letters.
^!+F12:: {
    chars := "abcdefghijklmnopqrstuvwxyz"
    length := 16

    result := ""

    loop length {
        result .= SubStr(chars, Random(1, StrLen(chars)), 1)
    }

    SendText(result)
}

; Ctrl + Alt + Shift + Delete force closes active process.
^!+Delete::
{
    activePID := WinGetPID("A")

    ProcessClose(activePID)
}
