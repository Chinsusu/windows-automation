; server_gui.au3
#include <GUIConstantsEx.au3>
#include <GuiListView.au3>
#include <GuiMenu.au3>
#include <WindowsConstants.au3>
#include <File.au3>
#include <Clipboard.au3>
#include "server_db.au3"
#include "server_http_listener.au3"
#include "server_commands_catalog.au3"

; Đăng ký cleanup khi app thoát (bất kỳ cách nào)
OnAutoItExitRegister("_AppCleanup")

Global $hGUI = GUICreate("Automation Control", 1200, 700)
Global $lv = GUICtrlCreateListView("Select|IP|Hostname|OS|Version|Status|Last Message|Last Seen", 10, 10, 900, 500)

; Set ListView style with checkboxes and column widths
_GUICtrlListView_SetExtendedListViewStyle($lv, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_CHECKBOXES))
_GUICtrlListView_SetColumnWidth($lv, 0, 60)  ; Select (checkbox)
_GUICtrlListView_SetColumnWidth($lv, 1, 130) ; IP
_GUICtrlListView_SetColumnWidth($lv, 2, 110) ; Hostname
_GUICtrlListView_SetColumnWidth($lv, 3, 80)  ; OS
_GUICtrlListView_SetColumnWidth($lv, 4, 70)  ; Version
_GUICtrlListView_SetColumnWidth($lv, 5, 70)  ; Status
_GUICtrlListView_SetColumnWidth($lv, 6, 190) ; Last Message
_GUICtrlListView_SetColumnWidth($lv, 7, 180) ; Last Seen

Global $btnSend = GUICtrlCreateButton("Send Command", 930, 10, 240, 40)
Global $btnBuild = GUICtrlCreateButton("Build & Publish", 930, 60, 240, 40)
Global $btnCopyMsg = GUICtrlCreateButton("Copy Selected Message", 930, 110, 240, 40)

; Log area - height giảm xuống 130px để chừa chỗ cho Close button
Global $log = GUICtrlCreateEdit("", 10, 520, 1160, 130)

; Nút Close (góc dưới bên phải) - đặt ở Y=655
Global $btnClose = GUICtrlCreateButton("Close", 10, 655, 150, 30)

; Register ListView click handler
GUIRegisterMsg($WM_NOTIFY, "_ListView_WM_NOTIFY")

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
            _SendCommandDialog()
        Case $btnBuild
            ; TODO: call builder + R2 uploader
            GUICtrlSetData($log, GUICtrlRead($log) & "Build & Publish clicked" & @CRLF)
        Case $btnCopyMsg
            _CopySelectedMessage()
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
Global $gClientCache  ; Store: IP => "status|message|last_seen"

; --- Copy Selected Message Button ---
Func _CopySelectedMessage()
    ; Get selected row
    Local $iSelected = _GUICtrlListView_GetSelectedIndices($lv)
    If $iSelected = "" Then
        MsgBox(48, "Copy Message", "Please select a client row first")
        Return
    EndIf
    
    ; Get first selected item
    Local $aSelected = StringSplit($iSelected, "|")
    If $aSelected[0] > 0 Then
        Local $iItem = Int($aSelected[1])
        Local $sMessage = _GUICtrlListView_GetItemText($lv, $iItem, 6)
        
        If $sMessage <> "" Then
            ClipPut($sMessage)
            GUICtrlSetData($log, GUICtrlRead($log) & "[COPY] " & $sMessage & @CRLF)
            MsgBox(64, "Copied", "Message copied to clipboard:" & @CRLF & @CRLF & $sMessage, 2)
        Else
            MsgBox(48, "Copy Message", "Selected row has no message")
        EndIf
    EndIf
EndFunc

; --- Send Command Dialog ---
Func _SendCommandDialog()
    ; Get checked clients
    Local $checkedIPs = ""
    For $i = 0 To _GUICtrlListView_GetItemCount($lv) - 1
        If _GUICtrlListView_GetItemChecked($lv, $i) Then
            Local $ip = _GUICtrlListView_GetItemText($lv, $i, 1)
            If $ip <> "" Then $checkedIPs &= $ip & "|"
        EndIf
    Next
    
    If $checkedIPs = "" Then
        MsgBox(48, "Send Command", "Please select at least one client (check the boxes)")
        Return
    EndIf
    
    ; Simple input dialog for command type and args
    Local $examples = "Enter command (examples):" & @CRLF & _
                      "SHELL {" & Chr(34) & "cmd" & Chr(34) & ":" & Chr(34) & "ipconfig" & Chr(34) & "}" & @CRLF & _
                      "SHELL {" & Chr(34) & "cmd" & Chr(34) & ":" & Chr(34) & "ping google.com" & Chr(34) & "}" & @CRLF & _
                      "OPEN_URL {" & Chr(34) & "url" & Chr(34) & ":" & Chr(34) & "https://google.com" & Chr(34) & "}"
    Local $input = InputBox("Send Command", $examples, "", " M", 500, 250)
    
    If @error Or $input = "" Then Return
    
    ; Parse command: "TYPE {json}"
    Local $spacePos = StringInStr($input, " ")
    If $spacePos = 0 Then
        MsgBox(16, "Error", "Invalid format. Use: COMMAND_TYPE {json}")
        Return
    EndIf
    
    Local $cmdType = StringStripWS(StringLeft($input, $spacePos - 1), 3)
    Local $cmdArgs = StringStripWS(StringMid($input, $spacePos + 1), 3)
    
    ; Validate that args is valid JSON (starts with { and ends with })
    If Not (StringLeft($cmdArgs, 1) = "{" And StringRight($cmdArgs, 1) = "}") Then
        MsgBox(16, "Error", "Arguments must be valid JSON object: {key:value}" & @CRLF & "Got: " & $cmdArgs)
        Return
    EndIf
    
    ; Queue task for each checked client
    Local $ips = StringSplit($checkedIPs, "|", 2)
    Local $count = 0
    For $i = 0 To UBound($ips) - 1
        If $ips[$i] <> "" Then
            ; Find client_id from IP
            Local $cid = _GetClientIdByIP($ips[$i])
            If $cid <> "" Then
                _DB_QueueTask($cid, $cmdType, $cmdArgs)
                $count += 1
            EndIf
        EndIf
    Next
    
    GUICtrlSetData($log, GUICtrlRead($log) & "[TASK] Queued " & $cmdType & " for " & $count & " client(s)" & @CRLF)
EndFunc

Func _GetClientIdByIP($ip)
    ; Read clients.json to find client_id by IP
    Local $file = @ScriptDir & "\..\db\clients.json"
    If Not FileExists($file) Then Return ""
    
    Local $json = _ReadFile($file)
    If $json = "" Or $json = "[]" Then Return ""
    
    ; Simple JSON parsing - find objects with matching ip_local or ip_public
    Local $searchPatterns[2] = ['"ip_local":"' & $ip & '"', '"ip_public":"' & $ip & '"']
    
    For $p = 0 To 1
        Local $pos = StringInStr($json, $searchPatterns[$p])
        If $pos > 0 Then
            ; Find the client_id in the same object
            ; Look backwards to find the start of this object
            Local $objStart = 0
            For $i = $pos To 1 Step -1
                If StringMid($json, $i, 1) = "{" Then
                    $objStart = $i
                    ExitLoop
                EndIf
            Next
            
            If $objStart > 0 Then
                ; Extract client_id from this object
                Local $cidPattern = '"client_id":"(.*?)"'
                Local $objSection = StringMid($json, $objStart, $pos - $objStart + 50)
                Local $matches = StringRegExp($objSection, $cidPattern, 1)
                If Not @error And UBound($matches) > 0 Then
                    Return $matches[0]
                EndIf
            EndIf
        EndIf
    Next
    
    Return ""
EndFunc

; --- ListView Click Handler for copying message ---
Func _ListView_WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $wParam
    Local $hWndFrom, $iCode, $tNMHDR
    $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    $hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
    $iCode = DllStructGetData($tNMHDR, "Code")
    
    Switch $hWndFrom
        Case GUICtrlGetHandle($lv)
            Switch $iCode
                Case $NM_CLICK, $NM_DBLCLK  ; Single or double click
                    Local $tInfo = DllStructCreate($tagNMITEMACTIVATE, $lParam)
                    Local $iItem = DllStructGetData($tInfo, "Index")
                    Local $iSubItem = DllStructGetData($tInfo, "SubItem")
                    
                    ; If clicked on message column (column 6)
                    If $iSubItem = 6 And $iItem >= 0 Then
                        Local $sMessage = _GUICtrlListView_GetItemText($lv, $iItem, 6)
                        If $sMessage <> "" Then
                            ClipPut($sMessage)
                            ; Show brief tooltip or status (only if not already showing)
                            ToolTip("✓ Copied: " & StringLeft($sMessage, 50) & "...")
                            ; Set a timer to hide tooltip
                            AdlibRegister("_HideTooltip", 1500)
                            
                            ; Also log to GUI log area
                            GUICtrlSetData($log, GUICtrlRead($log) & "[COPY] " & $sMessage & @CRLF)
                        EndIf
                    EndIf
                    
                Case $NM_RCLICK  ; Right click - show context menu
                    Local $tInfo = DllStructCreate($tagNMITEMACTIVATE, $lParam)
                    Local $iItem = DllStructGetData($tInfo, "Index")
                    
                    If $iItem >= 0 Then
                        ; Get message from clicked row
                        Local $sMessage = _GUICtrlListView_GetItemText($lv, $iItem, 6)
                        If $sMessage <> "" Then
                            ; Show context menu
                            Local $hMenu = _GUICtrlMenu_CreatePopup()
                            _GUICtrlMenu_InsertMenuItem($hMenu, 0, "Copy Message", 1000)
                            _GUICtrlMenu_InsertMenuItem($hMenu, 1, "Copy Full Row", 1001)
                            
                            Local $iRet = _GUICtrlMenu_TrackPopupMenu($hMenu, $hWndFrom, -1, -1, 1, 1, 2)
                            
                            Switch $iRet
                                Case 1000  ; Copy Message
                                    ClipPut($sMessage)
                                    ToolTip("✓ Message copied!", MouseGetPos(0), MouseGetPos(1) - 30)
                                    AdlibRegister("_HideTooltip", 1500)
                                    GUICtrlSetData($log, GUICtrlRead($log) & "[COPY] " & $sMessage & @CRLF)
                                    
                                Case 1001  ; Copy Full Row
                                    Local $sFullRow = ""
                                    For $c = 0 To 7
                                        $sFullRow &= _GUICtrlListView_GetItemText($lv, $iItem, $c) & @TAB
                                    Next
                                    ClipPut($sFullRow)
                                    ToolTip("✓ Full row copied!", MouseGetPos(0), MouseGetPos(1) - 30)
                                    AdlibRegister("_HideTooltip", 1500)
                            EndSwitch
                            
                            _GUICtrlMenu_DestroyMenu($hMenu)
                        EndIf
                    EndIf
            EndSwitch
    EndSwitch
    Return $GUI_RUNDEFMSG
EndFunc

Func _HideTooltip()
    ; Unregister first to prevent multiple timers
    AdlibUnRegister("_HideTooltip")
    ToolTip("")
EndFunc

Func _UI_RefreshClients()
    Local $a, $rows, $i, $idx
    
    _DB_GetClientsForUI($a, $rows)
    If $rows <= 0 Then
        _GUICtrlListView_DeleteAllItems($lv)
        $gClientCache = ""
        Return
    EndIf

    ; Build IP->row index map from current ListView
    Local $currentIPs = ""
    For $i = 0 To _GUICtrlListView_GetItemCount($lv) - 1
        $currentIPs &= _GUICtrlListView_GetItemText($lv, $i, 1) & "|" ; Column 1 = IP
    Next

    _GUICtrlListView_BeginUpdate($lv)
    
    ; Process each client from DB
    For $i = 1 To $rows
        Local $ip = $a[$i][1]
        Local $status = $a[$i][5]
        Local $msg = $a[$i][6]
        Local $lastSeen = $a[$i][7]
        Local $dataHash = $status & "|" & $msg & "|" & $lastSeen
        
        ; Check if this client changed
        Local $cacheKey = $ip
        Local $oldHash = ""
        If IsDeclared("gClientCache") And IsString($gClientCache) Then
            Local $pos = StringInStr($gClientCache, $cacheKey & "=")
            If $pos > 0 Then
                Local $endPos = StringInStr($gClientCache, ";", 0, 1, $pos)
                If $endPos > 0 Then
                    $oldHash = StringMid($gClientCache, $pos + StringLen($cacheKey & "="), $endPos - $pos - StringLen($cacheKey & "="))
                EndIf
            EndIf
        EndIf
        
        ; Find if IP already exists in ListView
        Local $found = False
        Local $rowIdx = -1
        For $j = 0 To _GUICtrlListView_GetItemCount($lv) - 1
            If _GUICtrlListView_GetItemText($lv, $j, 1) = $ip Then
                $found = True
                $rowIdx = $j
                ExitLoop
            EndIf
        Next
        
        If $found And $dataHash = $oldHash Then
            ; No change - skip this row
            ContinueLoop
        EndIf
        
        If $found Then
            ; Update existing row
            Local $wasChecked = _GUICtrlListView_GetItemChecked($lv, $rowIdx)
            _GUICtrlListView_SetItemText($lv, $rowIdx, $a[$i][2], 2)  ; Hostname
            _GUICtrlListView_SetItemText($lv, $rowIdx, $a[$i][3], 3)  ; OS
            _GUICtrlListView_SetItemText($lv, $rowIdx, $a[$i][4], 4)  ; Version
            _GUICtrlListView_SetItemText($lv, $rowIdx, $status, 5)    ; Status
            _GUICtrlListView_SetItemText($lv, $rowIdx, $msg, 6)       ; Last Message
            _GUICtrlListView_SetItemText($lv, $rowIdx, $lastSeen, 7)  ; Last Seen
            If $wasChecked Then _GUICtrlListView_SetItemChecked($lv, $rowIdx, True)
        Else
            ; Add new row - column 0 is Select (empty), column 1 is IP
            $idx = _GUICtrlListView_AddItem($lv, "")  ; Select column
            _GUICtrlListView_AddSubItem($lv, $idx, $ip, 1)
            _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][2], 2)  ; Hostname
            _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][3], 3)  ; OS
            _GUICtrlListView_AddSubItem($lv, $idx, $a[$i][4], 4)  ; Version
            _GUICtrlListView_AddSubItem($lv, $idx, $status, 5)
            _GUICtrlListView_AddSubItem($lv, $idx, $msg, 6)
            _GUICtrlListView_AddSubItem($lv, $idx, $lastSeen, 7)
        EndIf
        
        ; Update cache
        If Not IsDeclared("gClientCache") Or Not IsString($gClientCache) Then $gClientCache = ""
        $gClientCache = StringRegExpReplace($gClientCache, $cacheKey & "=[^;]*;", "")  ; Remove old
        $gClientCache &= $cacheKey & "=" & $dataHash & ";"  ; Add new
    Next
    
    _GUICtrlListView_EndUpdate($lv)
EndFunc

; Helper function to read file contents
Func _ReadFile($p)
    If Not FileExists($p) Then Return ""
    Local $h = FileOpen($p, 0)
    If $h = -1 Then Return ""
    Local $d = FileRead($h)
    FileClose($h)
    Return $d
EndFunc
