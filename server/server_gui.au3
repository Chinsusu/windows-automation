; server_gui.au3
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include "server_db.au3"
#include "server_http_listener.au3"
#include "server_commands_catalog.au3"

Global $hGUI = GUICreate("Automation Control", 1200, 700)
Global $lv = GUICtrlCreateListView("ClientID|IP|Hostname|OS|Version|Status|Last Message|Last Seen", 10, 10, 900, 500)
Global $btnSend = GUICtrlCreateButton("Send Command", 930, 10, 240, 40)
Global $btnBuild = GUICtrlCreateButton("Build & Publish", 930, 60, 240, 40)
Global $log = GUICtrlCreateEdit("", 10, 520, 1160, 160)
GUISetState(@SW_SHOW)

_DB_Init()
_Listener_AttachGui($log, $lv)
_Listener_Start(8080)

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnSend
            ; TODO: open dialog and queue task into DB
            GUICtrlSetData($log, GUICtrlRead($log) & "Send Command clicked" & @CRLF)
        Case $btnBuild
            ; TODO: call builder + R2 uploader
            GUICtrlSetData($log, GUICtrlRead($log) & "Build & Publish clicked" & @CRLF)
    EndSwitch
    ; TODO: refresh listview from DB
    Sleep(200)
WEnd
