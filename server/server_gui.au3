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

; TEMP: Comment out to test event loop
; _DB_Init()
; _Listener_AttachGui($log, $lv)
; _Listener_Start(8080)
GUICtrlSetData($log, "[STARTUP] DB and Listener DISABLED for testing" & @CRLF)

While 1
    Local $msg = GUIGetMsg()
    
    ; Debug: log ALL events (comment out after debug)
    If $msg <> 0 Then
        GUICtrlSetData($log, GUICtrlRead($log) & "[DEBUG] Event: " & $msg & " (Close btn ID: " & $btnClose & ")" & @CRLF)
    EndIf
    
    Switch $msg
        Case $GUI_EVENT_CLOSE
            GUICtrlSetData($log, GUICtrlRead($log) & "[1] X button clicked" & @CRLF)
            _SafeExit()
        Case $btnSend
            ; TODO: open dialog and queue task into DB
            GUICtrlSetData($log, GUICtrlRead($log) & "Send Command clicked" & @CRLF)
        Case $btnBuild
            ; TODO: call builder + R2 uploader
            GUICtrlSetData($log, GUICtrlRead($log) & "Build & Publish clicked" & @CRLF)
        Case $btnClose
            GUICtrlSetData($log, GUICtrlRead($log) & "[1] Close button clicked" & @CRLF)
            _SafeExit()
    EndSwitch
    ; TODO: refresh listview from DB
    Sleep(50)  ; Faster response to button clicks
WEnd

; --- Graceful exit helpers ---
Func _SafeExit()
    GUICtrlSetData($log, GUICtrlRead($log) & "[2] _SafeExit called" & @CRLF)
    Sleep(100)  ; Give time to show message
    
    GUICtrlSetData($log, GUICtrlRead($log) & "[3] Calling ProcessClose..." & @CRLF)
    Sleep(100)
    
    ; Quick exit - no cleanup, just kill
    ProcessClose(@AutoItPID)
    
    GUICtrlSetData($log, GUICtrlRead($log) & "[4] After ProcessClose (should never see this)" & @CRLF)
EndFunc

Func _AppCleanup()
    ; Emergency cleanup
    AdlibUnRegister("_Listener_Pump")
EndFunc
