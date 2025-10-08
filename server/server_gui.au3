; server_gui.au3
#include <GUIConstantsEx.au3>
#include <GuiListView.au3>
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

; Register ListView refresh every 1 second
AdlibRegister("_UI_RefreshClients", 1000)

; File logging for debug
Global $hLogFile = FileOpen(@ScriptDir & "\..\logs\gui_debug.log", 1)

While 1
    Local $msg = GUIGetMsg()
    
    ; Debug: log events to FILE (not GUI to avoid lag)
    If $msg <> 0 Then
        FileWrite($hLogFile, @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " Event: " & $msg & " (Close btn: " & $btnClose & ")" & @CRLF)
        FileFlush($hLogFile)
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
    AdlibUnRegister("_UI_RefreshClients")
EndFunc

; --- ListView refresh from DB ---
Global $gLastHash = ""

Func _UI_RefreshClients()
    Local $a, $rows
    ; CSV storage doesn't need initialization check
    _DB_GetClientsForUI($a, $rows)
    If $rows <= 0 Then
        _GUICtrlListView_DeleteAllItems($lv)
        Return
    EndIf

    ; Create simple hash from client_id+status+last_seen to detect changes
    Local $h = ""
    For $i = 1 To $rows
        $h &= $a[$i][0] & "|" & $a[$i][5] & "|" & $a[$i][7] & ";"
    Next
    
    ; Only refresh if data changed
    If ($h == $gLastHash) Then Return
    $gLastHash = $h

    ; Update ListView
    _GUICtrlListView_BeginUpdate($lv)
    _GUICtrlListView_DeleteAllItems($lv)

    For $i = 1 To $rows
        Local $idx = _GUICtrlListView_AddItem($lv, $a[$i][0])           ; ClientID
        _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][1], 1)            ; IP
        _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][2], 2)            ; Hostname
        _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][3], 3)            ; OS
        _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][4], 4)            ; Version
        _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][5], 5)            ; Status
        _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][6], 6)            ; Last Message
        _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][7], 7)            ; Last Seen
    Next
    _GUICtrlListView_EndUpdate($lv)
EndFunc
