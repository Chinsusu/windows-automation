; server_gui.au3
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include "server_db.au3"
#include "server_http_listener.au3"
#include "server_commands_catalog.au3"

; Đăng ký cleanup khi app thoát (bất kỳ cách nào)
OnAutoItExitRegister("_AppCleanup")

Global $hGUI = GUICreate("Automation Control", 1200, 700)
Global $lv = GUICtrlCreateListView("ClientID|IP|Hostname|OS|Version|Status|Last Message|Last Seen", 10, 10, 900, 500)
Global $btnSend = GUICtrlCreateButton("Send Command", 930, 10, 240, 40)
Global $btnBuild = GUICtrlCreateButton("Build & Publish", 930, 60, 240, 40)

; Log area - height giảm xuống 130px để chừa chỗ cho Close button
Global $log = GUICtrlCreateEdit("", 10, 520, 1160, 130)

; Nút Close (góc dưới bên phải) - đặt ở Y=655
Global $btnClose = GUICtrlCreateButton("Close", 10, 655, 150, 30)
GUISetState(@SW_SHOW)

_DB_Init()
_Listener_AttachGui($log, $lv)
_Listener_Start(8080)

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            _SafeExit()
        Case $btnSend
            ; TODO: open dialog and queue task into DB
            GUICtrlSetData($log, GUICtrlRead($log) & "Send Command clicked" & @CRLF)
        Case $btnBuild
            ; TODO: call builder + R2 uploader
            GUICtrlSetData($log, GUICtrlRead($log) & "Build & Publish clicked" & @CRLF)
        Case $btnClose
            _SafeExit()
    EndSwitch
    ; TODO: refresh listview from DB
    Sleep(200)
WEnd

; --- Graceful exit helpers ---
Func _SafeExit()
    GUICtrlSetState($btnClose, $GUI_DISABLE)
    GUICtrlSetData($log, GUICtrlRead($log) & @YEAR & "-" & @MON & "-" & @MDAY & "T" & @HOUR & ":" & @MIN & ":" & @SEC & "  Shutting down..." & @CRLF)
    _Listener_Stop()
    GUIDelete($hGUI)
    Exit
EndFunc

Func _AppCleanup()
    ; đảm bảo listener được stop nếu thoát đột ngột
    _Listener_Stop()
EndFunc
