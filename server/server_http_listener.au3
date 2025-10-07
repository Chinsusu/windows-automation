; server_http_listener.au3 — fixed
; Minimal HTTP listener for Windows Automation (AutoIt)
; - Handles: /health, /cb, /tasks, /task_result, /agent/latest, /manifest
; - SQLite persistence: db/automation.db
; - GUI hooks: _Listener_AttachGui($edtLog, $lv)
; NOTE: keep <= 500 lines

#include-once
#include <Array.au3>
#include <Date.au3>
#include <String.au3>
#include <Inet.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>

; ---------- Globals ----------
Global $gSrvSock = -1, $gPort = 8080
Global $gDB = 0, $gDbPath = @ScriptDir & "\..\db\automation.db"
Global $gAttachedLog = -1, $gAttachedLV = -1
Global $gApiKey = EnvGet("X_API_KEY") ; optional auth header for /cb & /task_result
Global Const $MAX_BODY = 1048576 ; 1MB cap

; ---------- Public API ----------
Func _Listener_AttachGui($hEditLogCtrl, $hListViewCtrl)
    $gAttachedLog = $hEditLogCtrl
    $gAttachedLV  = $hListViewCtrl
EndFunc

Func _Listener_Start($port = 8080)
    $gPort = $port
    _EnsureDir(@ScriptDir & "\..\db")
    _EnsureDir(@ScriptDir & "\..\logs")

    TCPStartup()
    ; Bind tất cả giao diện để client máy khác kết nối được
    $gSrvSock = TCPListen("0.0.0.0", $gPort, 100)
    If $gSrvSock = -1 Then
        _LogUI("HTTP listener start FAILED on 0.0.0.0:" & $gPort)
        Return SetError(1, 0, 0)
    EndIf

    _DB_Startup()
    Local $lanIP = _GetLANIP()
    _LogUI("HTTP listener started at 0.0.0.0:" & $gPort & "  (local IP: " & $lanIP & ")")

    ; pump every 200ms (was 50ms - too fast, blocked GUI event loop)
    AdlibRegister("_Listener_Pump", 200)
    Return 1
EndFunc

Func _Listener_Stop()
    AdlibUnRegister("_Listener_Pump")
    If $gSrvSock <> -1 Then TCPCloseSocket($gSrvSock)
    $gSrvSock = -1
    _DB_Shutdown()
    TCPShutdown()
    _LogUI("HTTP listener stopped")
EndFunc

; ---------- Pump ----------
Func _Listener_Pump()
    If $gSrvSock = -1 Then Return
    Local $cSock = TCPAccept($gSrvSock)
    If $cSock = -1 Then Return

    ; Read request (headers)
    Local $raw = _RecvToDoubleCRLF($cSock)
    If $raw = "" Then
        _SendHTTP($cSock, 400, "text/plain", "Bad Request")
        TCPCloseSocket($cSock)
        Return
    EndIf

    Local $req = _ParseRequestHeaders($raw)
    If @error Then
        _SendHTTP($cSock, 400, "text/plain", "Malformed")
        TCPCloseSocket($cSock)
        Return
    EndIf

    ; Read body if present
    Local $hdrs = $req.Item("headers") ; <-- biến tách riêng để truyền vào hàm (fix line 85: ByRef)
    Local $cl = _HeaderGet($hdrs, "Content-Length")
    Local $body = ""
    If Number($cl) > 0 Then
        $body = _RecvExact($cSock, Number($cl))
        If @error Then
            _SendHTTP($cSock, 400, "text/plain", "Body read error")
            TCPCloseSocket($cSock)
            Return
        EndIf
    EndIf
    $req.Item("body") = $body

    ; Dispatch
    Local $path = $req.Item("path")
    Switch $path
        Case "/health"
            _SendHTTP($cSock, 200, "text/plain", "ok")

        Case "/cb"
            If StringUpper($req.Item("method")) <> "POST" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                If Not _AuthOK($hdrs) Then
                    _SendHTTP($cSock, 401, "text/plain", "Unauthorized")
                Else
                    _HandleCB($req, $cSock)
                EndIf
            EndIf

        Case "/tasks"
            If StringUpper($req.Item("method")) <> "GET" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                _HandleTasks($req, $cSock)
            EndIf

        Case "/task_result"
            If StringUpper($req.Item("method")) <> "POST" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                If Not _AuthOK($hdrs) Then
                    _SendHTTP($cSock, 401, "text/plain", "Unauthorized")
                Else
                    _HandleTaskResult($req, $cSock)
                EndIf
            EndIf

        Case "/agent/latest"
            _HandleLatest($cSock)

        Case "/manifest"
            _HandleManifest($cSock)

        Case Else
            _SendHTTP($cSock, 404, "text/plain", "Not Found")
    EndSwitch

    TCPCloseSocket($cSock)
EndFunc

; ---------- Handlers ----------
Func _HandleCB(ByRef $req, $cSock)
    _LogUI("[CB] Handler started")
    
    ; Step 1: Parse JSON body
    Local $body = $req.Item("body")
    _LogUI("[CB] Body length: " & StringLen($body))
    
    Local $cid = _JsonGetStr($body, "client_id")
    Local $status = _JsonGetStr($body, "status")
    Local $message = _JsonGetStr($body, "message")
    Local $ip_local = _JsonGetStr($body, "ip_local")
    Local $ts = _JsonGetStr($body, "ts")
    If $ts = "" Then $ts = _NowTs()
    
    _LogUI("[CB] Parsed - cid: " & $cid & ", status: " & $status)

    If $cid = "" Then
        _LogUI("[CB] ERROR: Missing client_id")
        _SendHTTP($cSock, 400, "text/plain", "Missing client_id")
        Return
    EndIf

    ; Step 2: DB Upsert with error handling
    Local $ip_public = ""
    _LogUI("[CB] Calling _DB_UpsertClient...")
    
    _DB_UpsertClient($cid, $ip_public, $ip_local, $status, $message, $ts)
    
    If @error Then
        _LogUI("[CB] ERROR: DB upsert failed - " & @error)
        _SendHTTP($cSock, 500, "text/plain", "Database error")
        Return
    EndIf
    
    _LogUI("[CB] SUCCESS: " & $cid & " [" & $status & "] " & $message)
    _SendHTTP($cSock, 200, "text/plain", "ok")
EndFunc

Func _HandleTasks(ByRef $req, $cSock)
    Local $cid = _QueryGet($req.Item("query"), "client_id")
    If $cid = "" Then
        _SendHTTP($cSock, 400, "application/json", '{"error":"missing client_id"}')
        Return
    EndIf

    Local $row = _DB_GetNextTask($cid)
    If @error Or UBound($row) = 0 Then
        _SendEmpty($cSock, 204)
        Return
    EndIf

    ; row: [task_id, type, args]
    Local $task_id = $row[0]
    Local $type    = $row[1]
    Local $args    = $row[2]
    _DB_MarkTaskSent($task_id)

    Local $argsOut = "{}"
    If $args <> "" Then $argsOut = $args

    Local $json = '{"task_id":"' & $task_id & '","type":"' & $type & '","args":' & $argsOut & ',"timeout":30000}'
    _LogUI("[TASK] → " & $cid & " : " & $type)
    _SendHTTP($cSock, 200, "application/json", $json)
EndFunc

Func _HandleTaskResult(ByRef $req, $cSock)
    Local $cid = _JsonGetStr($req.Item("body"), "client_id")
    Local $task_id = _JsonGetStr($req.Item("body"), "task_id")
    Local $ok = _JsonGetBool($req.Item("body"), "ok")
    Local $result = _JsonGetStr($req.Item("body"), "result")
    Local $err = _JsonGetStr($req.Item("body"), "err")

    If $task_id = "" Then
        _SendHTTP($cSock, 400, "text/plain", "Missing task_id")
        Return
    EndIf

    _DB_SaveResult($task_id, $ok, $result, $err)
    Local $okText = "0"
    If $ok Then $okText = "1"
    _LogUI("[DONE] " & $cid & " #" & $task_id & " ok=" & $okText & " " & $result & " " & $err)
    _SendHTTP($cSock, 200, "text/plain", "ok")
EndFunc

Func _HandleLatest($cSock)
    Local $m = _ReadFile(@ScriptDir & "\..\manifests\manifest.json")
    If $m = "" Then
        _SendHTTP($cSock, 404, "text/plain", "manifest not found")
        Return
    EndIf
    Local $latest = _JsonGetStr($m, "latest")
    If $latest = "" Then $latest = "0.0.0"
    _SendHTTP($cSock, 200, "text/plain", $latest)
EndFunc

Func _HandleManifest($cSock)
    Local $m = _ReadFile(@ScriptDir & "\..\manifests\manifest.json")
    If $m = "" Then
        _SendHTTP($cSock, 404, "text/plain", "manifest not found")
        Return
    EndIf
    _SendHTTP($cSock, 200, "application/json", $m)
EndFunc

; ---------- DB ----------
Func _DB_Startup()
    _SQLite_Startup()
    _SQLite_Open($gDbPath, $gDB)
    Local $sql1 = "CREATE TABLE IF NOT EXISTS clients (" & _
        "client_id TEXT PRIMARY KEY, ip_public TEXT, ip_local TEXT, hostname TEXT, os TEXT, arch TEXT," & _
        "version TEXT, status TEXT, last_message TEXT, last_seen TEXT);"
    Local $sql2 = "CREATE TABLE IF NOT EXISTS tasks (" & _
        "task_id TEXT PRIMARY KEY, client_id TEXT, type TEXT, args TEXT, status TEXT, result TEXT, created_at TEXT, executed_at TEXT);"
    _SQLite_Exec($gDB, $sql1)
    _SQLite_Exec($gDB, $sql2)
    _SQLite_Exec($gDB, "CREATE INDEX IF NOT EXISTS idx_tasks_client ON tasks(client_id);")
    _SQLite_Exec($gDB, "CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);")
EndFunc

Func _DB_Shutdown()
    If $gDB <> 0 Then _SQLite_Close($gDB)
    $gDB = 0
    _SQLite_Shutdown()
EndFunc

Func _DB_UpsertClient($cid, $ip_public, $ip_local, $status, $message, $ts)
    Local $cidq = _Q($cid), $ipq = _Q($ip_public), $ilq = _Q($ip_local), $stq = _Q($status), $msgq = _Q($message), $tsq = _Q($ts)

    ; CHECK tồn tại client
    Local $a, $iRows, $iCols
    _SQLite_GetTable2d($gDB, "SELECT client_id FROM clients WHERE client_id=" & $cidq, $a, $iRows, $iCols)
    If @error Or $iRows = 0 Then
        ; INSERT
        Local $sqlIns = "INSERT INTO clients(client_id,ip_public,ip_local,status,last_message,last_seen) VALUES(" & _
                        $cidq & "," & $ipq & "," & $ilq & "," & $stq & "," & $msgq & "," & $tsq & ");"
        _SQLite_Exec($gDB, $sqlIns)
    Else
        ; UPDATE
        Local $sqlUpd = "UPDATE clients SET ip_public=" & $ipq & ", ip_local=" & $ilq & ", status=" & $stq & _
                        ", last_message=" & $msgq & ", last_seen=" & $tsq & " WHERE client_id=" & $cidq & ";"
        _SQLite_Exec($gDB, $sqlUpd)
    EndIf
EndFunc

Func _DB_GetNextTask($cid)
    Local $cidq = _Q($cid)
    Local $sql = "SELECT task_id, type, args FROM tasks WHERE client_id=" & $cidq & " AND status='queued' " & _
                 "ORDER BY datetime(created_at) LIMIT 1;"

    Local $a, $iRows, $iCols
    _SQLite_GetTable2d($gDB, $sql, $a, $iRows, $iCols)
    If @error Or $iRows = 0 Then
        Local $empty[0]
        SetError(1)
        Return $empty
    EndIf

    ; _SQLite_GetTable2d trả 2D array, hàng 0 là header → dữ liệu ở hàng 1
    Local $row[3]
    $row[0] = $a[1][0] ; task_id
    $row[1] = $a[1][1] ; type
    $row[2] = $a[1][2] ; args
    Return $row
EndFunc

Func _DB_MarkTaskSent($task_id)
    Local $tidq = _Q($task_id)
    _SQLite_Exec($gDB, "UPDATE tasks SET status='sent' WHERE task_id=" & $tidq & ";")
EndFunc

Func _DB_SaveResult($task_id, $ok, $result, $err)
    Local $tidq = _Q($task_id)
    Local $st = "error"
    If $ok Then $st = "done"
    Local $resq = _Q($result), $erq = _Q($err)
    Local $now = _Q(_NowTs())
    _SQLite_Exec($gDB, "UPDATE tasks SET status='" & $st & "', result=" & $resq & ", executed_at=" & $now & " WHERE task_id=" & $tidq & ";")
EndFunc

; ---------- Helpers ----------
Func _GetLANIP()
    ; Try to find 192.168.x.x IP address
    For $i = 1 To 4
        Local $ip = Execute("@IPAddress" & $i)
        If StringLeft($ip, 8) = "192.168." Then Return $ip
    Next
    ; Fallback to first adapter
    Return @IPAddress1
EndFunc

Func _EnsureDir($p)
    If Not FileExists($p) Then DirCreate($p)
EndFunc

Func _LogUI($s)
    Local $line = _NowTs() & "  " & $s & @CRLF
    If $gAttachedLog <> -1 Then GUICtrlSetData($gAttachedLog, GUICtrlRead($gAttachedLog) & $line)
EndFunc

Func _Q($s) ; simple SQL quote
    If $s = "" Then Return "NULL"
    Return "'" & StringReplace($s, "'", "''") & "'"
EndFunc

Func _ReadFile($p)
    If Not FileExists($p) Then Return ""
    Local $h = FileOpen($p, 0)
    If $h = -1 Then Return ""
    Local $d = FileRead($h)
    FileClose($h)
    Return $d
EndFunc

Func _AuthOK($hdrs)
    If $gApiKey = "" Then Return True
    Local $key = _HeaderGet($hdrs, "X-Api-Key")
    Return ($key = $gApiKey)
EndFunc

; ----- HTTP parsing/sending -----
Func _RecvToDoubleCRLF($sock)
    Local $buf = ""
    Local $stamp = TimerInit()
    While 1
        Local $chunk = TCPRecv($sock, 4096)
        If @error Then ExitLoop
        If $chunk = "" Then
            If TimerDiff($stamp) > 5000 Then ExitLoop
            Sleep(10)
            ContinueLoop
        EndIf
        $buf &= BinaryToString($chunk)
        If StringInStr($buf, @CRLF & @CRLF) Then ExitLoop
        If StringLen($buf) > 8192 Then ExitLoop
    WEnd
    Return $buf
EndFunc

Func _RecvExact($sock, $len)
    If $len > $MAX_BODY Then SetError(1, 0, "") ; cap
    Local $buf = ""
    Local $got = 0
    Local $stamp = TimerInit()
    While $got < $len
        Local $need = $len - $got
        Local $chunk = TCPRecv($sock, $need)
        If @error Then SetError(1, 0, "")
        If $chunk = "" Then
            If TimerDiff($stamp) > 5000 Then SetError(1, 0, "")
            Sleep(10)
            ContinueLoop
        EndIf
        $buf &= BinaryToString($chunk)
        $got = StringLen($buf)
    WEnd
    Return $buf
EndFunc

Func _ParseRequestHeaders($raw)
    Local $lines = StringSplit(StringStripCR($raw), @LF, 3)
    If UBound($lines) < 2 Then Return SetError(1, 0, 0)
    Local $first = $lines[0]
    Local $sp = StringSplit($first, " ", 3)
    If UBound($sp) < 2 Then Return SetError(1, 0, 0)

    Local $method = $sp[0]
    Local $full   = $sp[1]
    Local $path = $full, $query = ""
    Local $qpos = StringInStr($full, "?", 0, 1)
    If $qpos > 0 Then
        $path = StringLeft($full, $qpos - 1)
        $query = StringMid($full, $qpos + 1)
    EndIf

    ; headers -> 2D array [n][2]
    Local $hdrs[0][2]
    For $i = 1 To UBound($lines) - 1
        Local $ln = $lines[$i]
        If $ln = "" Then ExitLoop
        Local $p = StringInStr($ln, ":", 0, 1)
        If $p > 0 Then
            Local $k = StringStripWS(StringLeft($ln, $p - 1), 3)
            Local $v = StringStripWS(StringMid($ln, $p + 1), 3)
            ReDim $hdrs[UBound($hdrs) + 1][2]
            $hdrs[UBound($hdrs) - 1][0] = $k
            $hdrs[UBound($hdrs) - 1][1] = $v
        EndIf
    Next

    ; Use COM dictionary via Add/Item (không dùng property chấm)
    Local $req = ObjCreate("Scripting.Dictionary")
    $req.Add("method",  $method)
    $req.Add("path",    $path)
    $req.Add("query",   $query)
    $req.Add("headers", $hdrs)
    $req.Add("body",    "")
    Return $req
EndFunc

Func _HeaderGet($hdrs, $key)
    For $i = 0 To UBound($hdrs) - 1
        If StringLower($hdrs[$i][0]) = StringLower($key) Then Return $hdrs[$i][1]
    Next
    Return ""
EndFunc

Func _QueryGet($q, $key)
    If $q = "" Then Return ""
    Local $parts = StringSplit($q, "&", 3)
    For $i = 0 To UBound($parts) - 1
        Local $kv = StringSplit($parts[$i], "=", 3)
        If UBound($kv) >= 1 Then
            If $kv[0] = $key Then
                If UBound($kv) = 1 Then Return ""
                Return _URLDecode($kv[1])
            EndIf
        EndIf
    Next
    Return ""
EndFunc

Func _URLDecode($s)
    $s = StringReplace($s, "+", " ")
    Local $i = 1
    While $i <= StringLen($s)
        If StringMid($s, $i, 1) = "%" And $i + 2 <= StringLen($s) Then
            Local $hex = StringMid($s, $i + 1, 2)
            $s = StringLeft($s, $i - 1) & Chr(Dec($hex)) & StringMid($s, $i + 3)
        EndIf
        $i += 1
    WEnd
    Return $s
EndFunc

Func _SendHTTP($sock, $code, $ctype, $body)
    Local $status = "200 OK"
    Switch $code
        Case 200
            $status = "200 OK"
        Case 204
            $status = "204 No Content"
        Case 400
            $status = "400 Bad Request"
        Case 401
            $status = "401 Unauthorized"
        Case 404
            $status = "404 Not Found"
        Case 405
            $status = "405 Method Not Allowed"
        Case Else
            $status = $code & " OK"
    EndSwitch
    Local $hdr = "HTTP/1.1 " & $status & @CRLF & _
                 "Content-Type: " & $ctype & @CRLF & _
                 "Content-Length: " & StringLen($body) & @CRLF & _
                 "Connection: close" & @CRLF & @CRLF
    TCPSend($sock, $hdr & $body)
EndFunc

Func _SendEmpty($sock, $code)
    Local $hdr = "HTTP/1.1 " & $code & " No Content" & @CRLF & _
                 "Content-Length: 0" & @CRLF & _
                 "Connection: close" & @CRLF & @CRLF
    TCPSend($sock, $hdr)
EndFunc

; --- Timestamp helper to avoid name clash with Date.au3's _NowCalc()
Func _NowTs()
    ; ISO-like timestamp: YYYY-MM-DDTHH:MM:SS
    Return @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
           "T" & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)
EndFunc

; ----- Tiny JSON helpers (string-only + bool) -----
Func _JsonGetStr($json, $key)
    Local $pat = '"' & $key & '"\s*:\s*"(.*?)"'
    Local $m = StringRegExp($json, $pat, 1)
    If @error Or UBound($m) = 0 Then Return ""
    Return $m[0]
EndFunc

Func _JsonGetBool($json, $key)
    Local $pat = '"' & $key & '"\s*:\s*(true|false)'
    Local $m = StringRegExp($json, $pat, 1)
    If @error Or UBound($m) = 0 Then Return False
    Return (StringLower($m[0]) = "true")
EndFunc
