; server_http_listener.au3
; Minimal HTTP listener for Windows Automation (AutoIt)
; - Handles: /cb, /tasks, /task_result, /agent/latest, /manifest
; - SQLite persistence: db/automation.db
; - GUI hooks: _Listener_AttachGui($edtLog, $lv)
; NOTE: keep <= 500 lines

#include-once
#include <Array.au3>
#include <Date.au3>
#include <String.au3>
#include <Inet.au3>
#include <WinAPIShPath.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>

; ---------- Globals ----------
Global $gSrvSock = -1, $gPort = 8080
Global $gDB = 0, $gDbPath = @ScriptDir & "\..\db\automation.db"
Global $gAttachedLog = -1, $gAttachedLV = -1
Global $gApiKey = EnvGet("X_API_KEY") ; optional auth header check for /cb & /task_result
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
    ; Bind to 0.0.0.0 to listen on all interfaces
    $gSrvSock = TCPListen("0.0.0.0", $gPort, 100)
    If $gSrvSock = -1 Then
        _LogUI("HTTP listener start FAILED on port " & $gPort)
        Return SetError(1, 0, 0)
    EndIf

    _DB_Startup()
    ; Get LAN IP (192.168.x.x)
    Local $ip = _GetLANIP()
    _LogUI("HTTP listener started at 0.0.0.0:" & $gPort & "  (local IP: " & $ip & ")")

    ; pump every 50ms
    AdlibRegister("_Listener_Pump", 50)
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

    ; Read body if needed
    Local $body = ""
    Local $cl = _HeaderGet($req.headers, "Content-Length")
    If $cl > 0 Then
        $body = _RecvExact($cSock, $cl)
        If @error Then
            _SendHTTP($cSock, 400, "text/plain", "Body read error")
            TCPCloseSocket($cSock)
            Return
        EndIf
    EndIf
    $req.body = $body
    ; Không có macro @TCPRemoteHost hợp lệ; để trống hoặc suy từ header
    $req.remote = ""

    ; Dispatch
    Local $path = $req.path
    Switch $path
        Case "/health"
            _SendHTTP($cSock, 200, "text/plain", "ok")
            ; không log health để tránh spam

        Case "/cb"
            If StringUpper($req.method) <> "POST" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                If Not _AuthOK($req) Then
                    _SendHTTP($cSock, 401, "text/plain", "Unauthorized")
                Else
                    _HandleCB($req, $cSock)
                EndIf
            EndIf

        Case "/tasks"
            If StringUpper($req.method) <> "GET" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                _HandleTasks($req, $cSock)
            EndIf

        Case "/task_result"
            If StringUpper($req.method) <> "POST" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                If Not _AuthOK($req) Then
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
    Local $cid = _JsonGetStr($req.body, "client_id")
    Local $status = _JsonGetStr($req.body, "status")
    Local $message = _JsonGetStr($req.body, "message")
    Local $ip_local = _JsonGetStr($req.body, "ip_local")
    Local $ts = _JsonGetStr($req.body, "ts")
    If $ts = "" Then $ts = _GetTimestamp()

    If $cid = "" Then
        _SendHTTP($cSock, 400, "text/plain", "Missing client_id")
        Return
    EndIf

    Local $ip_public = _RemoteIP($req)
    _DB_UpsertClient($cid, $ip_public, $ip_local, $status, $message, $ts)

    _LogUI("[CB] " & $cid & " @" & $ip_public & " [" & $status & "] " & $message)
    _SendHTTP($cSock, 200, "text/plain", "ok")
EndFunc

Func _HandleTasks(ByRef $req, $cSock)
    Local $cid = _QueryGet($req.query, "client_id")
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

    Local $json = '{"task_id":"' & $task_id & '","type":"' & $type & '","args":' & _
                  ($args = "" ? "{}" : $args) & ',"timeout":30000}'
    _LogUI("[TASK] → " & $cid & " : " & $type)
    _SendHTTP($cSock, 200, "application/json", $json)
EndFunc

Func _HandleTaskResult(ByRef $req, $cSock)
    Local $cid = _JsonGetStr($req.body, "client_id")
    Local $task_id = _JsonGetStr($req.body, "task_id")
    Local $ok = _JsonGetBool($req.body, "ok")
    Local $result = _JsonGetStr($req.body, "result")
    Local $err = _JsonGetStr($req.body, "err")

    If $task_id = "" Then
        _SendHTTP($cSock, 400, "text/plain", "Missing task_id")
        Return
    EndIf

    _DB_SaveResult($task_id, $ok, $result, $err)
    _LogUI("[DONE] " & $cid & " #" & $task_id & " ok=" & ($ok ? "1":"0") & " " & $result & " " & $err)
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
    Local $rc = _SQLite_GetTable2d($gDB, "SELECT client_id FROM clients WHERE client_id=" & $cidq, $a)
    If @error Or UBound($a) < 2 Then
        Local $sql = "INSERT INTO clients(client_id,ip_public,ip_local,status,last_message,last_seen) VALUES(" & _
            $cidq & "," & $ipq & "," & $ilq & "," & $stq & "," & $msgq & "," & $tsq & ");"
        _SQLite_Exec($gDB, $sql)
    Else
        Local $sql = "UPDATE clients SET ip_public=" & $ipq & ", ip_local=" & $ilq & ", status=" & $stq & _
            ", last_message=" & $msgq & ", last_seen=" & $tsq & " WHERE client_id=" & $cidq & ";"
        _SQLite_Exec($gDB, $sql)
    EndIf
EndFunc

Func _DB_GetNextTask($cid)
    Local $cidq = _Q($cid)
    Local $sql = "SELECT task_id, type, args FROM tasks WHERE client_id=" & $cidq & " AND status='queued' ORDER BY datetime(created_at) LIMIT 1;"
    Local $a
    _SQLite_GetTable2d($gDB, $sql, $a)
    If @error Or UBound($a) < 2 Then
        Local $empty[0]
        SetError(1)
        Return $empty
    EndIf
    Local $row[3]
    $row[0] = $a[1][0]
    $row[1] = $a[1][1]
    $row[2] = $a[1][2]
    Return $row
EndFunc

Func _DB_MarkTaskSent($task_id)
    Local $tidq = _Q($task_id)
    _SQLite_Exec($gDB, "UPDATE tasks SET status='sent' WHERE task_id=" & $tidq & ";")
EndFunc

Func _DB_SaveResult($task_id, $ok, $result, $err)
    Local $tidq = _Q($task_id)
    Local $st = $ok ? "done" : "error"
    Local $resq = _Q($result), $erq = _Q($err)
    Local $now = _Q(_GetTimestamp())
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
    Local $line = _GetTimestamp() & "  " & $s & @CRLF
    If $gAttachedLog <> -1 Then GUICtrlSetData($gAttachedLog, GUICtrlRead($gAttachedLog) & $line)
    ; (Optional) update ListView outside this file if muốn
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

Func _AuthOK(ByRef $req)
    If $gApiKey = "" Then Return True
    Local $h = $req.headers
    Local $key = ""
    For $i = 0 To UBound($h) - 1
        If StringLower($h[$i][0]) = "x-api-key" Then
            $key = $h[$i][1]
            ExitLoop
        EndIf
    Next
    Return ($key = $gApiKey)
EndFunc

Func _RemoteIP(ByRef $req)
    ; Ưu tiên X-Forwarded-For (nếu chạy sau proxy)
    Local $xff = _HeaderGet($req.headers, "X-Forwarded-For")
    If $xff <> "" Then Return StringStripWS(StringSplit($xff, ",")[1], 3)
    ; Không có cách lấy remote socket IP trực tiếp ở đây → trả rỗng
    Return ""
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

    ; headers
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

    Local $req = ObjCreate("Scripting.Dictionary")
    $req.method = $method
    $req.path = $path
    $req.query = $query
    $req.headers = $hdrs
    $req.body = ""
    $req.remote = ""
    Return $req
EndFunc

Func _HeaderGet(ByRef $hdrs, $key)
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

Func _GetTimestamp()
    Return @YEAR & "-" & @MON & "-" & @MDAY & "T" & @HOUR & ":" & @MIN & ":" & @SEC
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
