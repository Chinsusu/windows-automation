; Windows Automation Client Agent - Status Reporter
; Reports local IP, public IP, and status to server
; Server: 192.168.2.101:8080
#RequireAdmin
#include <WinHttp.au3>
#include <Constants.au3>

; ================== CONFIGURATION ==================
Global Const $SERVER_URL = "http://192.168.2.101:8080/cb"
Global Const $INTERVAL = 600000  ; 10 minutes (600000 ms)
Global Const $LOG_FILE = @TempDir & "\StatusAgent.log"

; Networking/timeouts
Global Const $HTTP_TIMEOUT_RESOLVE = 5000       ; ms
Global Const $HTTP_TIMEOUT_CONNECT = 5000       ; ms
Global Const $HTTP_TIMEOUT_SEND = 5000          ; ms
Global Const $HTTP_TIMEOUT_RECV = 5000          ; ms
Global Const $PS_TIMEOUT_SEC = 12               ; PowerShell Invoke-RestMethod timeout
Global Const $CHILD_WAIT_TIMEOUT_SEC = 20       ; Max wait for child process (ipconfig/PowerShell)
Global Const $CURL_TIMEOUT_SEC = 8              ; Max wait for curl icanhazip.com
Global Const $LOG_MAX_SIZE = 524288             ; 512 KB log rotate threshold

; ================== MAIN FUNCTIONS ==================

; Get local IP address
Func _GetLocalIP()
    Local $ip = "unknown"
    
    ; Try AutoIt macros first
    If @IPAddress1 <> "0.0.0.0" And @IPAddress1 <> "" Then
        Return @IPAddress1
    EndIf
    
    If @IPAddress2 <> "0.0.0.0" And @IPAddress2 <> "" Then
        Return @IPAddress2
    EndIf
    
    ; Fallback to ipconfig (bounded read with timeout)
    Local $ipconfig = Run(@ComSpec & " /c ipconfig", "", @SW_HIDE, $STDOUT_CHILD)
    Local $output = ""
    Local $t = TimerInit()
    While ProcessExists($ipconfig)
        $output &= StdoutRead($ipconfig)
        If TimerDiff($t) > 3000 Then ExitLoop ; 3s cap
        Sleep(50)
    WEnd
    ; Drain remaining buffer
    $output &= StdoutRead($ipconfig)
    If ProcessExists($ipconfig) Then ProcessClose($ipconfig)
    
    Local $matches = StringRegExp($output, "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", 3)
    If Not @error And UBound($matches) > 0 Then
        For $i = 0 To UBound($matches) - 1
            Local $testIP = $matches[$i]
            If Not StringInStr($testIP, "127.0.0.") And _
               Not StringInStr($testIP, "169.254.") And _
               Not StringInStr($testIP, "255.255.255.") And _
               $testIP <> "0.0.0.0" Then
                Return $testIP
            EndIf
        Next
    EndIf
    
    Return $ip
EndFunc

; Validate IPv4/IPv6 string
Func _IsValidIP($s)
    If $s = "" Then Return False
    ; IPv4 simple check
    If StringRegExp($s, "^\d{1,3}(\.\d{1,3}){3}$") Then Return True
    ; IPv6 basic check (accepts compressed forms)
    If StringInStr($s, ":") And StringRegExp($s, "^[0-9A-Fa-f:]+$") And StringLen($s) <= 45 Then Return True
    Return False
EndFunc

; Prefer curl to get public IP (handles routers blocking ICMP)
Func _GetPublicIP_Curl()
    Local $cmd = 'curl -s --max-time 6 https://icanhazip.com'
    Local $pid = Run(@ComSpec & " /c " & $cmd, "", @SW_HIDE, $STDOUT_CHILD)
    If $pid = 0 Then Return "N/A"
    If Not ProcessWaitClose($pid, $CURL_TIMEOUT_SEC) Then
        ProcessClose($pid)
        Return "N/A"
    EndIf
    Local $out = StringStripWS(StdoutRead($pid), 3)
    If _IsValidIP($out) Then Return $out
    Return "N/A"
EndFunc

; HTTP POST JSON via WinHTTP with timeouts
Func _HttpPostJson($sURL, $sJSON)
    Local $aURL = _WinHttpCrackUrl($sURL)
    If @error Or UBound($aURL) < 8 Then Return SetError(1, 0, False)

    Local $scheme = $aURL[1]
    Local $host = $aURL[2]
    Local $port = $aURL[3]
    Local $path = $aURL[6] & $aURL[7]
    If $path = "" Then $path = "/"

    Local $hOpen = _WinHttpOpen()
    If @error Or $hOpen = 0 Then Return SetError(2, 0, False)
    _WinHttpSetTimeouts($hOpen, $HTTP_TIMEOUT_RESOLVE, $HTTP_TIMEOUT_CONNECT, $HTTP_TIMEOUT_SEND, $HTTP_TIMEOUT_RECV)

    Local $hConn = _WinHttpConnect($hOpen, $host, $port)
    If @error Or $hConn = 0 Then
        _WinHttpCloseHandle($hOpen)
        Return SetError(3, 0, False)
    EndIf

    Local $flags = 0
    If $scheme = $INTERNET_SCHEME_HTTPS Then $flags = $WINHTTP_FLAG_SECURE
    Local $hReq = _WinHttpOpenRequest($hConn, "POST", $path, Default, $WINHTTP_NO_REFERER, $WINHTTP_DEFAULT_ACCEPT_TYPES, $flags)
    If @error Or $hReq = 0 Then
        _WinHttpCloseHandle($hConn)
        _WinHttpCloseHandle($hOpen)
        Return SetError(4, 0, False)
    EndIf

    ; Headers
    _WinHttpAddRequestHeaders($hReq, "Content-Type: application/json", $WINHTTP_ADDREQ_FLAG_ADD)
    _WinHttpAddRequestHeaders($hReq, "User-Agent: StatusAgent/1.0", $WINHTTP_ADDREQ_FLAG_ADD)
    Local $apiKey = EnvGet("X_API_KEY")
    If $apiKey <> "" Then _WinHttpAddRequestHeaders($hReq, "X-Api-Key: " & $apiKey, $WINHTTP_ADDREQ_FLAG_ADD)

    ; Send body
    Local $b = Binary($sJSON)
    _WinHttpSendRequest($hReq, Default, $b)
    If @error Then
        _WinHttpCloseHandle($hReq)
        _WinHttpCloseHandle($hConn)
        _WinHttpCloseHandle($hOpen)
        Return SetError(5, 0, False)
    EndIf
    _WinHttpReceiveResponse($hReq)
    If @error Then
        _WinHttpCloseHandle($hReq)
        _WinHttpCloseHandle($hConn)
        _WinHttpCloseHandle($hOpen)
        Return SetError(6, 0, False)
    EndIf

    ; Status code
    Local $code = _WinHttpQueryHeaders($hReq, BitOR($WINHTTP_QUERY_STATUS_CODE, $WINHTTP_QUERY_FLAG_NUMBER))
    If @error Then $code = 0

    ; Drain response
    While _WinHttpQueryDataAvailable($hReq)
        Local $chunk = _WinHttpReadData($hReq)
        If @error Or $chunk = "" Then ExitLoop
        ; ignore body
    WEnd

    _WinHttpCloseHandle($hReq)
    _WinHttpCloseHandle($hConn)
    _WinHttpCloseHandle($hOpen)

    Return ($code >= 200 And $code < 300)
EndFunc

; Get public IP address using curl first, then WinHttp fallback
Func _GetPublicIP()
    ; Try curl (router may block ICMP, but HTTP should work)
    Local $curlIP = _GetPublicIP_Curl()
    If $curlIP <> "N/A" Then Return $curlIP

    Local $aServices[3][2] = [["icanhazip.com", "/"], ["api.ipify.org", "/"], ["ifconfig.me", "/ip"]]
    
    For $i = 0 To UBound($aServices) - 1
        Local $sHost = $aServices[$i][0]
        Local $sPath = $aServices[$i][1]
        
        ; Open WinHttp session with timeouts
        Local $hOpen = _WinHttpOpen()
        If @error Then ContinueLoop
        _WinHttpSetTimeouts($hOpen, $HTTP_TIMEOUT_RESOLVE, $HTTP_TIMEOUT_CONNECT, $HTTP_TIMEOUT_SEND, $HTTP_TIMEOUT_RECV)
        
        ; Connect to host
        Local $hConnect = _WinHttpConnect($hOpen, $sHost)
        If @error Then
            _WinHttpCloseHandle($hOpen)
            ContinueLoop
        EndIf
        
        ; Send GET request
        Local $hRequest = _WinHttpOpenRequest($hConnect, "GET", $sPath)
        If @error Then
            _WinHttpCloseHandle($hConnect)
            _WinHttpCloseHandle($hOpen)
            ContinueLoop
        EndIf
        
        _WinHttpSendRequest($hRequest)
        If @error Then
            _WinHttpCloseHandle($hRequest)
            _WinHttpCloseHandle($hConnect)
            _WinHttpCloseHandle($hOpen)
            ContinueLoop
        EndIf
        
        _WinHttpReceiveResponse($hRequest)
        If @error Then
            _WinHttpCloseHandle($hRequest)
            _WinHttpCloseHandle($hConnect)
            _WinHttpCloseHandle($hOpen)
            ContinueLoop
        EndIf
        
        ; Read response (drain fully)
        Local $sPublicIP = ""
        While _WinHttpQueryDataAvailable($hRequest)
            Local $chunk = _WinHttpReadData($hRequest)
            If @error Or $chunk = "" Then ExitLoop
            $sPublicIP &= $chunk
        WEnd
        $sPublicIP = StringStripWS($sPublicIP, 3)  ; Trim whitespace
        
        ; Clean up
        _WinHttpCloseHandle($hRequest)
        _WinHttpCloseHandle($hConnect)
        _WinHttpCloseHandle($hOpen)
        
        ; Validate IP format
        If _IsValidIP($sPublicIP) Then Return $sPublicIP
    Next
    
    Return "N/A"
EndFunc

; Generate client ID from computer name
Func _GetClientId()
    Local $hash = 0
    Local $name = @ComputerName
    For $i = 1 To StringLen($name)
        $hash = Mod($hash * 31 + Asc(StringMid($name, $i, 1)), 2147483647)
    Next
    Return "client_" & Hex($hash, 8)
EndFunc

; Send status to server
Func _SendStatus($localIP, $publicIP, $status)
    Local $clientId = _GetClientId()
    Local $json = '{' & _
        '"client_id":"' & $clientId & '",' & _
        '"ip":"' & $localIP & '",' & _
        '"public_ip":"' & $publicIP & '",' & _
        '"status":"' & $status & '",' & _
        '"message":"Agent reporting status: ' & $status & '",' & _
        '"computer":"' & @ComputerName & '"' & _
    '}'
    
    _Log("Sending: " & $json)
    
    Local $ok = _HttpPostJson($SERVER_URL, $json)
    If $ok Then
        _Log("Status sent successfully (WinHTTP)")
        Return True
    EndIf
    _Log("Failed to send status via WinHTTP")
    Return False
EndFunc

; Log function
Func _Log($msg)
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $line = $timestamp & " | " & $msg & @CRLF
    ConsoleWrite($line)
    ; Rotate if large
    If FileExists($LOG_FILE) Then
        Local $sz = FileGetSize($LOG_FILE)
        If @error = 0 And $sz > $LOG_MAX_SIZE Then
            If FileExists($LOG_FILE & ".1") Then FileDelete($LOG_FILE & ".1")
            FileMove($LOG_FILE, $LOG_FILE & ".1", 1)
        EndIf
    EndIf
    FileWrite($LOG_FILE, $line)
EndFunc

; Main execution
Func Main()
    _Log("==================== STATUS AGENT START ====================")
    _Log("Computer: " & @ComputerName & " | Client ID: " & _GetClientId())
    
    Local $localIP = _GetLocalIP()
    _Log("Local IP: " & $localIP)
    
    Local $publicIP = _GetPublicIP()
    _Log("Public IP: " & $publicIP)
    
    Local $status = ($publicIP <> "N/A") ? "online" : "offline"
    _Log("Status: " & $status)
    
    _SendStatus($localIP, $publicIP, $status)
    
    _Log("==================== STATUS AGENT END ====================")
EndFunc

; ================== ENTRY POINT ==================
; Check if running in service mode (loop every 10 minutes)
If $CmdLine[0] > 0 And $CmdLine[1] = "/service" Then
    _Log("Running in SERVICE mode (interval: " & ($INTERVAL / 60000) & " minutes)")
    While 1
        Main()
        Sleep($INTERVAL)
    WEnd
Else
    ; Run once
    _Log("Running in SINGLE mode")
    Main()
EndIf
