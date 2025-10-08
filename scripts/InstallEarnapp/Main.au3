; Main script để chạy tuần tự 4 script: Auto_Install, Click_Skip, Click_Signin, Copy_Url
; Script tổng hợp automation cài đặt EarnApp và gửi kết quả về server
#RequireAdmin
#include <MsgBoxConstants.au3>

; ================== CẤU HÌNH SERVER ==================
; Thay đổi IP và port server của bạn ở đây
Global Const $SERVER_URL = "http://192.168.2.101:8080/cb"

; ================== KHỞI TẠO ==================
ConsoleWrite("=== EARNAPP AUTOMATION MAIN SCRIPT ===" & @CRLF)
ConsoleWrite("Server URL: " & $SERVER_URL & @CRLF)

; Tạo file config để các script con đọc
Local $sConfigFile = @ScriptDir & "\config.ini"
IniWrite($sConfigFile, "Server", "URL", $SERVER_URL)
ConsoleWrite("Created config file: " & $sConfigFile & @CRLF)

Local $sDir = @ScriptDir
Local $sAutoIt = "C:\Program Files (x86)\AutoIt3\AutoIt3.exe"  ; Đường dẫn chính xác

; Hàm chạy script với kiểm tra
Func RunScript($sFileName, $sDescription)
    ConsoleWrite(@CRLF & "==================== " & $sDescription & " ====================" & @CRLF)
    
    Local $sFullPath = $sDir & "\" & $sFileName
    If Not FileExists($sFullPath) Then
        ConsoleWrite("[ERROR] Không tìm thấy file: " & $sFullPath & @CRLF)
        _SendErrorToServer("File not found: " & $sFileName)
        Return False
    EndIf

    If Not FileExists($sAutoIt) Then
        ConsoleWrite("[ERROR] Không tìm thấy AutoIt3.exe: " & $sAutoIt & @CRLF)
        _SendErrorToServer("AutoIt3.exe not found")
        Return False
    EndIf

    ConsoleWrite("[INFO] Chạy: " & $sFileName & @CRLF)
    Local $iPID = Run('"' & $sAutoIt & '" /ErrorStdOut "' & $sFullPath & '"', $sDir, @SW_SHOW)
    ProcessWaitClose($iPID)
    Local $iExitCode = @error
    
    If $iExitCode <> 0 Then
        ConsoleWrite("[ERROR] Lỗi chạy " & $sFileName & ": Exit code " & $iExitCode & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[SUCCESS] Hoàn thành: " & $sFileName & @CRLF)
    Return True
EndFunc

; Hàm gửi lỗi về server
Func _SendErrorToServer($errorMsg)
    Local $clientId = _GetClientId()
    Local $ip = _GetLocalIP()
    Local $json = '{"client_id":"' & $clientId & '","status":"FAILED","message":"' & $errorMsg & '","ip":"' & $ip & '","computer":"' & @ComputerName & '"}'
    
    ; Ghi JSON ra temp file để tránh vấn đề escape
    Local $jsonFile = @TempDir & "\earnapp_error.json"
    FileDelete($jsonFile)
    FileWrite($jsonFile, $json)
    
    Local $ps = 'powershell -NoProfile -Command "try { $json = Get-Content ''' & $jsonFile & ''' -Raw; Invoke-RestMethod -Uri ''' & $SERVER_URL & ''' -Method POST -Body $json -ContentType ''application/json'' -TimeoutSec 10 } catch { Write-Host ''FAILED'' }"'
    Run(@ComSpec & " /c " & $ps, "", @SW_HIDE)
    Sleep(1000)  ; Wait for callback
    FileDelete($jsonFile)
EndFunc

; Hàm lấy IP address
Func _GetLocalIP()
    Local $ip = "unknown"
    
    ; Method 1: Use @IPAddress1 (fastest)
    If @IPAddress1 <> "0.0.0.0" And @IPAddress1 <> "" Then
        Return @IPAddress1
    EndIf
    
    ; Method 2: Try other AutoIt IP macros
    If @IPAddress2 <> "0.0.0.0" And @IPAddress2 <> "" Then
        Return @IPAddress2
    EndIf
    
    ; Method 3: Use ipconfig
    Local $ipconfig = Run(@ComSpec & " /c ipconfig", "", @SW_HIDE, $STDOUT_CHILD)
    Local $output = ""
    While 1
        $output &= StdoutRead($ipconfig)
        If @error Then ExitLoop
    WEnd
    
    ; Look for any IPv4 pattern and skip loopback/link-local
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

Func _GetClientId()
    Local $hash = 0
    Local $name = @ComputerName
    For $i = 1 To StringLen($name)
        $hash = Mod($hash * 31 + Asc(StringMid($name, $i, 1)), 2147483647)
    Next
    Return "client_" & Hex($hash, 8)
EndFunc

; ================== WORKFLOW CHÍNH ==================

; Bước 1: Download và cài đặt
If Not RunScript("Auto_Install.au3", "STEP 1: Download & Install") Then
    ConsoleWrite("[FATAL] Cài đặt thất bại, dừng script" & @CRLF)
    Exit 1
EndIf

ConsoleWrite("[INFO] Chờ app khởi động..." & @CRLF)
Sleep(10000)

; Bước 2: Click Skip
If Not RunScript("Click_Skip.au3", "STEP 2: Click Skip Button") Then
    ConsoleWrite("[WARNING] Click Skip thất bại, tiếp tục..." & @CRLF)
EndIf

Sleep(2000)

; Bước 3: Click Sign In
If Not RunScript("Click_Signin.au3", "STEP 3: Click Sign In Button") Then
    ConsoleWrite("[WARNING] Click Sign In thất bại, tiếp tục..." & @CRLF)
EndIf

ConsoleWrite("[INFO] Chờ browser mở..." & @CRLF)
Sleep(10000)

; Bước 4: Copy URL và gửi về server
If Not RunScript("Copy_Url.au3", "STEP 4: Copy URL & Send to Server") Then
    ConsoleWrite("[ERROR] Lấy URL thất bại" & @CRLF)
    Exit 1
EndIf

ConsoleWrite(@CRLF & "========================================" & @CRLF)
ConsoleWrite("=== HOÀN THÀNH TẤT CẢ CÁC BƯỚC ===" & @CRLF)
ConsoleWrite("========================================" & @CRLF)

; Cleanup config file
FileDelete($sConfigFile)
