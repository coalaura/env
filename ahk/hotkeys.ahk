#SingleInstance Force

; PTT applications
GroupAdd "PTTApps", "ahk_exe FiveM_GTAProcess.exe"
GroupAdd "PTTApps", "Minecraft"
GroupAdd "PTTApps", "Feather Client"

IsPTTAppActive() => WinActive("ahk_group PTTApps")

; Check if PTT apps is focused
#HotIf IsPTTAppActive()

; ^ is push-to-talk
^::F7

#HotIf

; Check if PTT app is not focused
#HotIf !IsPTTAppActive()

; Remove double-press of ^ key
^::SendText("^")

#HotIf

; Remove double-press of ` key
`::SendText("``")
´::SendText("``")

; Right windows button locks screen
RWin::Send("#L")

; Ensure F7 is released when leaving PTT app
SetTimer CheckFocus, 200

; Release F7 if PTT app is not active
PTTActive := false

CheckFocus()
{
    global PTTActive

    if IsPTTAppActive() {
        PTTActive := true
    } else if (PTTActive && !GetKeyState("Alt", "P")) {
        PTTActive := false

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

; Ctrl + Alt + W inspect focused window.
^!w::
{
    hwnd := WinExist("A")
    if !hwnd {
        return
    }

    WinGetClientPos(&cx, &cy, &cw, &ch, hwnd)
    WinGetPos(&x, &y, &w, &h, hwnd)

    dpi := DllCall("User32\GetDpiForWindow", "Ptr", hwnd, "UInt")
    dpi := dpi ? dpi : 96
    scale := dpi / 96

    info :=
    (
    "Title:   " WinGetTitle(hwnd) "
    Process: " WinGetProcessName(hwnd) "
    PID:     " WinGetPID(hwnd) "
    Class:   " WinGetClass(hwnd) "
    Handle:  " Format("0x{:X}", hwnd) "
    - - - -
    Actual client: " cw " × " ch " px
    Normalized:    " Round(cw / scale) " × " Round(ch / scale) "
    Full window:   " w " × " h " px
    Position:      " x ", " y "
    - - - -
    DPI:   " dpi "
    Scale: " Round(scale * 100, 1) "%"
    )

    file := A_Temp "\window-info.txt"
    try FileDelete(file)
    FileAppend(info, file, "UTF-8")
    Run(file)
}
