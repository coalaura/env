#Requires AutoHotkey v2.0
#SingleInstance Force

; PTT applications
GroupAdd "PTTApps", "ahk_exe FiveM_GTAProcess.exe"
GroupAdd "PTTApps", "ahk_exe FiveM_b3788_GTAProcess.exe"
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
RWin::DllCall("User32\LockWorkStation")

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

; Release F8 if script exits
OnExit(ReleasePTT)

ReleasePTT(*)
{
    SendEvent("{F7 up}")
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
    "[Window]
    Title: " WinGetTitle(hwnd) "
    Class: " WinGetClass(hwnd) "
    HWND:  " Format("0x{:X}", hwnd) "

    [Process]
    Name: " WinGetProcessName(hwnd) "
    PID:  " WinGetPID(hwnd) "
    Path: " WinGetProcessPath(hwnd) "

    [Styles]
    Style:    " Format("0x{:08X}", WinGetStyle(hwnd)) "
    Ex-style: " Format("0x{:08X}", WinGetExStyle(hwnd)) "

    [Geometry]
    Client size: " cw " × " ch " px
    Client @dpi: " Round(cw / scale) " × " Round(ch / scale) " px
    Window size: " w " × " h " px
    Client pos:  " cx ", " cy "
    Window pos:  " x ", " y "

    [DPI]
    DPI:   " dpi "
    Scale: " Round(scale * 100, 1) "%"
    )

    file := A_Temp "\window-info.txt"

    try {
        f := FileOpen(file, "w", "UTF-8")

        f.Write(info)
        f.Close()

        Run(file)
    } catch Error as err {
        MsgBox("Could not create window information:`n" err.Message)
    }
}
