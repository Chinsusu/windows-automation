; server_gui_clients.au3
; GUI dạng bảng: chọn nhiều client (checkbox), hiển thị Index | IP | Status | Message
; Phía dưới có ô nhập URL + nút Send (OPEN_URL) và Update (UPDATE_AGENT)
; --- Yêu cầu: AutoIt 3, SciTE. Không phụ thuộc DB (demo dữ liệu mẫu).

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <GuiEdit.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <Array.au3>

Global Const $COLOR_GREEN  = 0x009E3A  ; Online
Global Const $COLOR_ORANGE = 0xFF8C00  ; Offline
Global Const $COLOR_BLUE   = 0x0078D7  ; Updating
Global Const $COLOR_BLACK  = 0x000000

; ---------------- GUI ----------------
Global $gGUI = GUICreate("Clients Control — Windows Automation", 1100, 420, -1, -1)
Global $lvID = GUICtrlCreateListView("Chọn/Hủy Chọn|Index|IP|Status|Message", 10, 10, 900, 270, BitOR($LVS_SHOWSELALWAYS, $LVS_REPORT))
Global $hLV = GUICtrlGetHandle($lvID)

_GUICtrlListView_SetExtendedListViewStyle($hLV, BitOR($LVS_EX_CHECKBOXES, $LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER))

; Set width cột
_GUICtrlListView_SetColumnWidth($hLV, 0, 140) ; Chọn/Hủy Chọn
_GUICtrlListView_SetColumnWidth($hLV, 1, 60)  ; Index
_GUICtrlListView_SetColumnWidth($hLV, 2, 150) ; IP
_GUICtrlListView_SetColumnWidth($hLV, 3, 100) ; Status
_GUICtrlListView_SetColumnWidth($hLV, 4, 430) ; Message

; Khu điều khiển bên dưới
GUICtrlCreateLabel("Command", 10, 298, 70, 20)
Global $cmbCmd = GUICtrlCreateCombo("OPEN_URL", 80, 292, 160, 24)
GUICtrlSetData($cmbCmd, "UPDATE_AGENT")

GUICtrlCreateLabel("URL", 260, 298, 30, 20)
Global $inpUrl = GUICtrlCreateInput("", 295, 293, 445, 24)

Global $btnSend   = GUICtrlCreateButton("Send",   760, 292, 70, 26, $BS_DEFPUSHBUTTON)
Global $btnUpdate = GUICtrlCreateButton("Update", 835, 292, 70, 26)

Global $btnSelectAll = GUICtrlCreateButton("Select all", 10, 326, 90, 26)
Global $btnClearAll  = GUICtrlCreateButton("Clear all",  105, 326, 90, 26)
Global $btnReload    = GUICtrlCreateButton("Reload",     200, 326, 90, 26)

; Khu log
GUICtrlCreateLabel("Logs", 930, 10, 160, 18)
Global $edtLog = GUICtrlCreateEdit("", 930, 30, 160, 350, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))

GUISetState(@SW_SHOW)

; -------------- Data demo --------------
; Bạn có thể thay bằng dữ liệu từ DB/HTTP. Ở đây là mảng mẫu.
Global $gRows = [ _
    ["", "01", "192.168.2.101", "Online",   "https://earnapp.com/dashboard"], _
    ["", "02", "192.168.2.102", "Online",   "https://youtube.com"], _
    ["", "03", "192.168.2.103", "Offline",  ""], _
    ["", "04", "192.168.2.104", "Offline",  ""], _
    ["", "05", "192.168.2.105", "Updating", ""], _
    ["", "10", "192.168.2.110", "Online",   "https://youtube.com"] _
]

; Load bảng
_LoadList($gRows)

; ---------------- Main loop ----------------
While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnSend
            _HandleSend()
        Case $btnUpdate
            _HandleUpdate()
        Case $btnSelectAll
            _List_CheckAll(True)
        Case $btnClearAll
            _List_CheckAll(False)
        Case $btnReload
            _ReloadDemo()
    EndSwitch
WEnd

; ==================== FUNCTIONS ====================

Func _LoadList(ByRef $rows)
    _GUICtrlListView_DeleteAllItems($hLV)
    For $i = 0 To UBound($rows) - 1
        Local $line = $rows[$i][0] & "|" & $rows[$i][1] & "|" & $rows[$i][2] & "|" & $rows[$i][3] & "|" & $rows[$i][4]
        Local $idItem = GUICtrlCreateListViewItem($line, $lvID)

        ; Tô màu theo Status (cả dòng — đơn giản & ổn định)
        Switch StringLower($rows[$i][3])
            Case "online"
                GUICtrlSetColor($idItem, $COLOR_GREEN)
            Case "offline"
                GUICtrlSetColor($idItem, $COLOR_ORANGE)
            Case "updating"
                GUICtrlSetColor($idItem, $COLOR_BLUE)
            Case Else
                GUICtrlSetColor($idItem, $COLOR_BLACK)
        EndSwitch
    Next
EndFunc

Func _List_GetItemCount()
    Return _GUICtrlListView_GetItemCount($hLV)
EndFunc

Func _List_GetCheckedIndexes()
    Local $n = _List_GetItemCount()
    Local $indices[0]
    For $i = 0 To $n - 1
        If _GUICtrlListView_GetCheckState($hLV, $i) Then
            _ArrayAdd($indices, $i)
        EndIf
    Next
    Return $indices
EndFunc

Func _List_CheckAll($state)
    Local $n = _List_GetItemCount()
    For $i = 0 To $n - 1
        _GUICtrlListView_SetCheckState($hLV, $i, $state)
    Next
EndFunc

Func _List_GetCell($row, $col)
    ; col: 0..4
    Return _GUICtrlListView_GetItemText($hLV, $row, $col)
EndFunc

Func _List_SetCell($row, $col, $text)
    _GUICtrlListView_SetItemText($hLV, $row, $text, $col)
EndFunc

Func _Log($s)
    Local $now = @HOUR & ":" & @MIN & ":" & @SEC & "  "
    GUICtrlSetData($edtLog, GUICtrlRead($edtLog) & $now & $s & @CRLF)
    _GUICtrlEdit_Scroll($edtLog, $SB_SCROLLCARET)
EndFunc

; ----- Nút Send: gửi OPEN_URL -----
Func _HandleSend()
    Local $cmd = GUICtrlRead($cmbCmd)
    If $cmd <> "OPEN_URL" Then
        _Log("⚠️ Command không phải OPEN_URL (đang chọn '" & $cmd & "').")
        Return
    EndIf

    Local $url = StringStripWS(GUICtrlRead($inpUrl), 3)
    Local $sel = _List_GetCheckedIndexes()
    If UBound($sel) = 0 Then
        _Log("⚠️ Chưa chọn client nào.")
        Return
    EndIf

    For $k = 0 To UBound($sel) - 1
        Local $r = $sel[$k]
        Local $ip = _List_GetCell($r, 2)
        ; nếu ô URL trống, dùng Message của dòng
        Local $rowUrl = _List_GetCell($r, 4)
        Local $finalUrl = ($url <> "") ? $url : $rowUrl
        If $finalUrl = "" Then
            _Log("⏭️ Bỏ qua " & $ip & " (không có URL).")
            ContinueLoop
        EndIf

        ; TODO: queue task OPEN_URL cho $ip (hoặc client_id) — ở đây demo log
        _Log("📤 Send OPEN_URL → " & $ip & "  (" & $finalUrl & ")")
        ; Ví dụ cập nhật Message của dòng bằng URL vừa gửi
        _List_SetCell($r, 4, $finalUrl)
    Next
EndFunc

; ----- Nút Update: gửi UPDATE_AGENT -----
Func _HandleUpdate()
    Local $sel = _List_GetCheckedIndexes()
    If UBound($sel) = 0 Then
        _Log("⚠️ Chưa chọn client nào.")
        Return
    EndIf
    For $k = 0 To UBound($sel) - 1
        Local $r = $sel[$k]
        Local $ip = _List_GetCell($r, 2)
        ; Đổi Status → Updating + màu xanh
        _List_SetCell($r, 3, "Updating")
        ; Đổi màu dòng (cả row)
        Local $itemID = _GUICtrlListView_GetItemParam($hLV, $r) ; không dùng được với GUICtrlSetColor
        ; -> dùng cách đơn giản: tạo lại màu bằng GUICtrlSetColor yêu cầu ControlID
        ; Cách này cần lưu ControlID từng row nếu muốn đổi lại màu sau này.
        ; Ở demo, mình reload để đồng bộ màu theo Status.
        _Log("📤 Send UPDATE_AGENT → " & $ip)
    Next
    ; Đồng bộ màu theo Status sau khi đổi (đơn giản & chắc)
    _SyncRowColors()
EndFunc

Func _SyncRowColors()
    ; Reload lại màu theo Status
    Local $n = _List_GetItemCount()
    For $i = 0 To $n - 1
        Local $status = _GUICtrlListView_GetItemText($hLV, $i, 3)
        ; Không có ControlID từng item -> refresh bằng cách xoá và thêm lại sẽ phức tạp.
        ; Giải pháp: clear & load lại toàn bảng từ model (nếu bạn có model).
        ; Ở demo, gọi _ReloadDemo() để reset màu chuẩn.
    Next
    _ReloadDemo() ; đơn giản: nạp lại từ $gRows
EndFunc

Func _ReloadDemo()
    ; Cập nhật lại $gRows từ nội dung hiện tại của ListView (để không mất thay đổi Message/Status)
    Local $n = _List_GetItemCount()
    ReDim $gRows[$n][5]
    For $i = 0 To $n - 1
        $gRows[$i][0] = ""                                 ; cột "Chọn/Hủy Chọn" để trống (checkbox mặc định)
        $gRows[$i][1] = _GUICtrlListView_GetItemText($hLV, $i, 1) ; Index
        $gRows[$i][2] = _GUICtrlListView_GetItemText($hLV, $i, 2) ; IP
        $gRows[$i][3] = _GUICtrlListView_GetItemText($hLV, $i, 3) ; Status
        $gRows[$i][4] = _GUICtrlListView_GetItemText($hLV, $i, 4) ; Message
    Next
    _LoadList($gRows)
EndFunc
