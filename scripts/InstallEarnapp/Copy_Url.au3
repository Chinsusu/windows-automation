; Script để tìm cửa sổ browser EarnApp và gửi URL về server
#include <MsgBoxConstants.au3>
#include <Constants.au3>

; Log file
Global $LOG_FILE = @TempDir & "\copy_url_debug.log"
FileDelete($LOG_FILE)

Func _Log($msg)
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $line = $timestamp & " | " & $msg & @CRLF
    ConsoleWrite($line)
    FileWrite($LOG_FILE, $line)
EndFunc

_Log("[Copy_Url] ==================== START ====================")
_Log("[Copy_Url] Script directory: " & @ScriptDir)
_Log("[Copy_Url] Log file: " & $LOG_FILE)

; Đọc server URL từ file config (được tạo bởi Main.au3)
Global $SERVER_URL = IniRead(@ScriptDir & "\config.ini", "Server", "URL", "http://192.168.2.101:8080/cb")
_Log("[Copy_Url] Server URL: " & $SERVER_URL)

; Sử dụng WinList để tìm cửa sổ
Local $aList = WinList()
Local $hBrowser = 0

_Log("[Copy_Url] Scanning " & $aList[0][0] & " windows...")

For $i = 1 To $aList[0][0]
    Local $hWnd = $aList[$i][1]
    If $hWnd And BitAND(WinGetState($hWnd), 2) Then  ; Visible
        Local $sTitle = WinGetTitle($hWnd)
        If StringInStr($sTitle, "EarnApp") Then
            _Log("[Copy_Url] Found EarnApp window: '" & $sTitle & "' HWND=" & $hWnd)
            
            Local $tBuffer = DllStructCreate("wchar[256]")
            DllCall("user32.dll", "int", "GetClassNameW", "hwnd", $hWnd, "struct*", $tBuffer, "int", 256)
            Local $sClass = DllStructGetData($tBuffer, 1)
            
            _Log("[Copy_Url]   Class: " & $sClass)
            
            If $sClass = "Chrome_WidgetWin_1" Then
                $hBrowser = $hWnd
                _Log("[Copy_Url] Found Chrome browser window!")
                ExitLoop
            EndIf
        EndIf
    EndIf
Next

If $hBrowser Then
    _Log("[Copy_Url] Activating browser window...")
    WinActivate($hBrowser)
    WinWaitActive($hBrowser, "", 5)

    ; Focus address bar và copy URL
    _Log("[Copy_Url] Selecting URL (Alt+D)...")
    Send("!d")  ; Alt + D
    Sleep(300)
    
    _Log("[Copy_Url] Copying URL (Ctrl+C)...")
    Send("^c")  ; Ctrl + C
    Sleep(300)

    ; Lấy URL từ clipboard
    Local $sURL = ClipGet()
    _Log("[Copy_Url] Clipboard content: '" & $sURL & "'")
    
    If $sURL <> "" And Not StringInStr($sURL, "Copy_Url") Then
        _Log("[Copy_Url] Got valid URL: " & $sURL)
        ; Send original URL to server (server will convert it)
        _SendToServer("SUCCESS", $sURL)
    Else
        _Log("[Copy_Url] ERROR: Failed to copy URL (got: '" & $sURL & "')")
        _SendToServer("FAILED", "Could not copy URL from browser - got: " & $sURL)
    EndIf
    
    ; Đóng browser window sau khi đã copy URL
    _Log("[Copy_Url] Closing browser window...")
    WinClose($hBrowser)
    Sleep(1000)
Else
    _Log("[Copy_Url] ERROR: Browser window NOT found")
    _SendToServer("FAILED", "Browser window not found")
EndIf

_Log("[Copy_Url] ==================== END ====================")

; Function to get local IP address
Func _GetLocalIP()
    Local $ip = "unknown"
    
    ; Method 1: Use @IPAddress1 (fastest)
    If @IPAddress1 <> "0.0.0.0" And @IPAddress1 <> "" Then
        $ip = @IPAddress1
        _Log("[Copy_Url] Found IP via @IPAddress1: " & $ip)
        Return $ip
    EndIf
    
    ; Method 2: Try other AutoIt IP macros
    If @IPAddress2 <> "0.0.0.0" And @IPAddress2 <> "" Then
        $ip = @IPAddress2
        _Log("[Copy_Url] Found IP via @IPAddress2: " & $ip)
        Return $ip
    EndIf
    
    ; Method 3: Use ipconfig with better regex (works on both English and Vietnamese Windows)
    Local $ipconfig = Run(@ComSpec & " /c ipconfig", "", @SW_HIDE, $STDOUT_CHILD)
    Local $output = ""
    While 1
        $output &= StdoutRead($ipconfig)
        If @error Then ExitLoop
    WEnd
    
    _Log("[Copy_Url] ipconfig output length: " & StringLen($output))
    
    ; Try multiple patterns for different Windows languages
    ; Pattern 1: English "IPv4 Address"
    Local $matches = StringRegExp($output, "IPv4 Address[.\s]*:\s*(\d+\.\d+\.\d+\.\d+)", 3)
    If Not @error And UBound($matches) > 0 Then
        ; Skip loopback and link-local addresses
        For $i = 0 To UBound($matches) - 1
            If Not StringInStr($matches[$i], "127.0.0.") And Not StringInStr($matches[$i], "169.254.") Then
                $ip = $matches[$i]
                _Log("[Copy_Url] Found IP via ipconfig (EN): " & $ip)
                Return $ip
            EndIf
        Next
    EndIf
    
    ; Pattern 2: Vietnamese "Địa chỉ IPv4" or just look for any IPv4 pattern
    $matches = StringRegExp($output, "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", 3)
    If Not @error And UBound($matches) > 0 Then
        ; Skip loopback, link-local, and common DNS/gateway addresses
        For $i = 0 To UBound($matches) - 1
            Local $testIP = $matches[$i]
            If Not StringInStr($testIP, "127.0.0.") And _
               Not StringInStr($testIP, "169.254.") And _
               Not StringInStr($testIP, "255.255.255.") And _
               Not StringInStr($testIP, ".0.0.0") And _
               $testIP <> "0.0.0.0" Then
                ; Likely a valid local IP
                $ip = $testIP
                _Log("[Copy_Url] Found IP via ipconfig (pattern): " & $ip)
                Return $ip
            EndIf
        Next
    EndIf
    
    _Log("[Copy_Url] WARNING: Could not determine IP address")
    Return $ip
EndFunc

; Function to send result to server
Func _SendToServer($status, $message)
    Local $clientId = _GetClientId()
    Local $ip = _GetLocalIP()
    
    ; Escape JSON values properly
    Local $jsonMessage = _JsonEscape($message)
    
    ; Build JSON with IP address
    Local $json = '{"client_id":"' & $clientId & '","status":"' & $status & '","message":"' & $jsonMessage & '","ip":"' & $ip & '","computer":"' & @ComputerName & '"}'
    
    _Log("[Copy_Url] Sending callback to: " & $SERVER_URL)
    _Log("[Copy_Url]   Client ID: " & $clientId)
    _Log("[Copy_Url]   IP: " & $ip)
    _Log("[Copy_Url]   Computer: " & @ComputerName)
    _Log("[Copy_Url]   Status: " & $status)
    _Log("[Copy_Url]   Message: " & $message)
    _Log("[Copy_Url]   JSON: " & $json)
    
    ; Ghi JSON ra temp file để tránh vấn đề escape trong PowerShell
    Local $jsonFile = @TempDir & "\earnapp_callback.json"
    FileDelete($jsonFile)
    FileWrite($jsonFile, $json)
    _Log("[Copy_Url]   JSON file: " & $jsonFile)
    
    ; Dùng file thay vì inline JSON
    Local $ps = 'powershell -NoProfile -Command "try { $json = Get-Content ''' & $jsonFile & ''' -Raw; Invoke-RestMethod -Uri ''' & $SERVER_URL & ''' -Method POST -Body $json -ContentType ''application/json'' -TimeoutSec 10; Write-Host ''OK'' } catch { Write-Host ''FAILED:'' $_.Exception.Message }"'
    
    _Log("[Copy_Url] Executing PowerShell callback...")
    Local $pid = Run(@ComSpec & " /c " & $ps, "", @SW_HIDE, $STDOUT_CHILD)
    Local $out = ""
    While 1
        $out &= StdoutRead($pid)
        If @error Then ExitLoop
    WEnd
    
    _Log("[Copy_Url] Callback response: " & $out)
    
    ; Cleanup temp file
    FileDelete($jsonFile)
    
    If StringInStr($out, "OK") Then
        _Log("[Copy_Url] ✓ Callback sent successfully")
    Else
        _Log("[Copy_Url] ✗ Callback failed: " & $out)
    EndIf
EndFunc

Func _GetClientId()
    Local $hash = 0
    Local $name = @ComputerName
    For $i = 1 To StringLen($name)
        $hash = Mod($hash * 31 + Asc(StringMid($name, $i, 1)), 2147483647)
    Next
    Return "client_" & Hex($hash, 8)
EndFunc

Func _JsonEscape($str)
    $str = StringReplace($str, "\", "\\")
    $str = StringReplace($str, '"', '\"')
    $str = StringReplace($str, @CRLF, "\n")
    $str = StringReplace($str, @LF, "\n")
    $str = StringReplace($str, @CR, "\r")
    $str = StringReplace($str, @TAB, "\t")
    Return $str
EndFunc
