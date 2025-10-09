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

; Tạo file config (đặt ở Temp) để các exe con đọc
Local $sConfigFile = @TempDir & "\config.ini"
IniWrite($sConfigFile, "Server", "URL", $SERVER_URL)
ConsoleWrite("Created config file: " & $sConfigFile & @CRLF)

; ================== NHÚNG VÀ GIẢI NÉN FILE CẦN THIẾT ==================
ConsoleWrite("Extracting embedded resources to Temp: " & @TempDir & @CRLF)
DirCreate(@TempDir & "\ImageSearchEx_UDF")
DirCreate(@TempDir & "\Image")
; Các EXE con
FileInstall("bin\Auto_Install.exe", @TempDir & "\Auto_Install.exe", 1)
FileInstall("bin\Click_Skip.exe", @TempDir & "\Click_Skip.exe", 1)
FileInstall("bin\Click_Signin.exe", @TempDir & "\Click_Signin.exe", 1)
FileInstall("bin\Copy_Url.exe", @TempDir & "\Copy_Url.exe", 1)
FileInstall("bin\Click_Accept.exe", @TempDir & "\Click_Accept.exe", 1)
; UDF DLL và file liên quan
FileInstall("ImageSearchEx_UDF\ImageSearchEx_x86.dll", @TempDir & "\ImageSearchEx_UDF\ImageSearchEx_x86.dll", 1)
FileInstall("ImageSearchEx_UDF\ImageSearchEx_Win7_x86.dll", @TempDir & "\ImageSearchEx_UDF\ImageSearchEx_Win7_x86.dll", 1)
FileInstall("ImageSearchEx_UDF\ImageSearchEx_x64.dll", @TempDir & "\ImageSearchEx_UDF\ImageSearchEx_x64.dll", 1)
FileInstall("ImageSearchEx_UDF\ImageSearchEx_Win7_x64.dll", @TempDir & "\ImageSearchEx_UDF\ImageSearchEx_Win7_x64.dll", 1)
FileInstall("ImageSearchEx_UDF\ImageSearchEx_UDF.au3", @TempDir & "\ImageSearchEx_UDF\ImageSearchEx_UDF.au3", 1)
; Ảnh
FileInstall("Image\skip.bmp", @TempDir & "\Image\skip.bmp", 1)
FileInstall("Image\Signin.bmp", @TempDir & "\Image\Signin.bmp", 1)
FileInstall("Image\Accept.bmp", @TempDir & "\Image\Accept.bmp", 1)
FileInstall("Image\Invite.bmp", @TempDir & "\Image\Invite.bmp", 1)
FileInstall("Image\Close_App.bmp", @TempDir & "\Image\Close_App.bmp", 1)
FileInstall("Image\Note.bmp", @TempDir & "\Image\Note.bmp", 1)
FileInstall("Image\Choose_Note.bmp", @TempDir & "\Image\Choose_Note.bmp", 1)
FileInstall("Image\Minimize.bmp", @TempDir & "\Image\Minimize.bmp", 1)

Local $sDir = @ScriptDir

; Hàm chạy EXE con (đã được nhúng và giải nén ra Temp)
Func RunSubExe($sExeName, $sDescription)
    ConsoleWrite(@CRLF & "==================== " & $sDescription & " ====================" & @CRLF)

    Local $sTempExe = @TempDir & "\" & $sExeName
    If Not FileExists($sTempExe) Then
        ConsoleWrite("[ERROR] Không tìm thấy file: " & $sTempExe & @CRLF)
        _SendErrorToServer("File not found: " & $sExeName)
        Return False
    EndIf

    ConsoleWrite("[INFO] Chạy: " & $sExeName & @CRLF)
    Local $iRC = RunWait('"' & $sTempExe & '"', @TempDir, @SW_SHOW)
    If @error Then
        ConsoleWrite("[ERROR] Lỗi chạy " & $sExeName & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[SUCCESS] Hoàn thành: " & $sExeName & @CRLF)
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
If Not RunSubExe("Auto_Install.exe", "STEP 1: Download & Install") Then
    ConsoleWrite("[FATAL] Cài đặt thất bại, dừng script" & @CRLF)
    Exit 1
EndIf

ConsoleWrite("[INFO] Chờ app khởi động..." & @CRLF)
Sleep(10000)

; Bước 2: Click Skip
If Not RunSubExe("Click_Skip.exe", "STEP 2: Click Skip Button") Then
    ConsoleWrite("[WARNING] Click Skip thất bại, tiếp tục..." & @CRLF)
EndIf

Sleep(2000)

; Bước 3: Click Sign In
If Not RunSubExe("Click_Signin.exe", "STEP 3: Click Sign In Button") Then
    ConsoleWrite("[WARNING] Click Sign In thất bại, tiếp tục..." & @CRLF)
EndIf

ConsoleWrite("[INFO] Chờ browser mở..." & @CRLF)
Sleep(10000)

; Bước 4: Copy URL và gửi về server
If Not RunSubExe("Copy_Url.exe", "STEP 4: Copy URL & Send to Server") Then
    ConsoleWrite("[ERROR] Lấy URL thất bại" & @CRLF)
    Exit 1
EndIf

ConsoleWrite("[INFO] Chờ app quay lại..." & @CRLF)
Sleep(15000)

; Bước 5: Click Accept sequence (Accept -> Invite -> Close_App -> Note -> Choose_Note -> Minimize)
If Not RunSubExe("Click_Accept.exe", "STEP 5: Click Accept Sequence") Then
    ConsoleWrite("[WARNING] Click Accept sequence thất bại, tiếp tục..." & @CRLF)
EndIf

ConsoleWrite(@CRLF & "========================================" & @CRLF)
ConsoleWrite("=== HOÀN THÀNH TẤT CẢ CÁC BƯỚC ===" & @CRLF)
ConsoleWrite("========================================" & @CRLF)

; Cleanup config file
FileDelete($sConfigFile)
