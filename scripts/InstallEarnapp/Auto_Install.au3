; earnapp-auto-install.au3
; Tải earnapp-latest.exe về Desktop và cài đặt tự động.
; Thứ tự: curl -> PowerShell -> InetGet. Cài: silent -> GUI automation.

#RequireAdmin
#include <InetConstants.au3>

Opt("MustDeclareVars", 1)
Opt("WinTitleMatchMode", 2) ; match chứa chuỗi trong tiêu đề

Local $URL = "https://earnapp.com/dashboard/download/win"
Local $OUT = @DesktopDir & "\earnapp-latest.exe"

; ================== DOWNLOAD ==================
Local $ok = False
Local $curlCmd = 'curl -fL -o "' & $OUT & '" "' & $URL & '"'
$ok = _RunAndCheck($curlCmd, $OUT)

If Not $ok Then
    Local $psInner = '[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; ' & _
                     'Invoke-WebRequest ''' & $URL & ''' -MaximumRedirection 10 -OutFile ''' & $OUT & ''''
    Local $psCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -Command "' & $psInner & '"'
    $ok = _RunAndCheck($psCmd, $OUT)
EndIf

If Not $ok Then
    Local $h = InetGet($URL, $OUT, $INET_FORCERELOAD)
    If @error Then
        $ok = False
    Else
        $ok = FileExists($OUT)
    EndIf
EndIf

If Not $ok Or Not FileExists($OUT) Then
    ConsoleWrite("Download failed." & @CRLF)
    Exit 1
EndIf

ConsoleWrite('Saved to "' & $OUT & '"' & @CRLF)

; ================== INSTALL ==================
If Not _InstallPackage($OUT) Then
    ConsoleWrite("Install failed." & @CRLF)
    Exit 2
EndIf

ConsoleWrite("Install completed." & @CRLF)
Exit 0

; ------------------ FUNCTIONS ------------------

Func _RunAndCheck($sCmd, $sOutPath)
    Local $rc = RunWait(@ComSpec & " /c " & $sCmd, "", @SW_HIDE)
    If $rc = 0 And FileExists($sOutPath) Then Return True
    Return False
EndFunc

Func _InstallPackage($sPath)
    Local $ext = StringLower(StringRight($sPath, 4))
    If $ext = ".msi" Then
        If _InstallMSI($sPath) Then Return True
    Else
        If _TrySilentExe($sPath) Then Return True
    EndIf
    ; fallback GUI automation
    Return _GuiInstall($sPath)
EndFunc

Func _InstallMSI($msi)
    Local $cmd = 'msiexec /i "' & $msi & '" /qn /norestart'
    Local $rc = RunWait(@ComSpec & " /c " & $cmd, "", @SW_HIDE)
    Return ($rc = 0)
EndFunc

Func _TrySilentExe($exe)
    ; Thử các kiểu silent phổ biến: NSIS/Inno/InstallShield…
    Local $flags[7] = ["/S", "/s", "/silent", "/verysilent", "/SILENT", "/VERYSILENT", "/quiet"]
    For $i = 0 To UBound($flags) - 1
        Local $pid = Run('"' & $exe & '" ' & $flags[$i], "", @SW_HIDE)
        If @error Then ContinueLoop
        If ProcessWaitClose($pid, 300) Then Return True ; 5 phút
        ProcessClose($pid)
    Next
    ; InstallShield kiểu /s /v"/qn"
    Local $pid2 = Run('"' & $exe & '" /s /v"/qn"', "", @SW_HIDE)
    If Not @error And ProcessWaitClose($pid2, 300) Then Return True
    ProcessClose($pid2)
    Return False
EndFunc

Func _GuiInstall($exe)
    ConsoleWrite("Falling back to GUI automation..." & @CRLF)
    Local $pid = Run('"' & $exe & '"', "", @SW_SHOW)
    If @error Then Return False

    ; Danh sách tiêu đề cửa sổ có thể gặp (có thể chỉnh thêm nếu cần)
    Local $TITLES[8] = ["EarnApp Setup", "EarnApp Installer", "Setup", "Install", "Installation", "Wizard", "Setup - EarnApp", "EarnApp"]

    Local $tStart = TimerInit()
    While ProcessExists($pid)
        For $i = 0 To UBound($TITLES) - 1
            Local $t = $TITLES[$i]
            If WinWaitActive($t, "", 1) Then
                _TickAllCheckboxes($t) ; tick mọi lựa chọn/option nhìn thấy
                ; Đồng ý điều khoản nếu có
                _ClickIfExists($t, "I &accept")
                _ClickIfExists($t, "&I accept")
                _ClickIfExists($t, "I accept")
                _ClickIfExists($t, "I &agree")
                _ClickIfExists($t, "&I agree")
                _ClickIfExists($t, "I agree")
                _ClickIfExists($t, "Accept")
                _ClickIfExists($t, "Agree")

                ; Tiếp tục/Install/Finish
                _ClickIfExists($t, "Next >")
                _ClickIfExists($t, "&Next >")
                _ClickIfExists($t, "Next")
                _ClickIfExists($t, "&Next")
                _ClickIfExists($t, "Install")
                _ClickIfExists($t, "&Install")
                _ClickIfExists($t, "Finish")
                _ClickIfExists($t, "&Finish")
                _ClickIfExists($t, "Close")
                _ClickIfExists($t, "&Close")
                Sleep(250)
            EndIf
        Next
        If TimerDiff($tStart) > 600000 Then ExitLoop ; 10 phút an toàn
        Sleep(150)
    WEnd

    ; chốt lại: nếu còn cửa sổ “Finish/Close”
    For $i = 0 To UBound($TITLES) - 1
        Local $t = $TITLES[$i]
        If WinExists($t) Then
            _ClickIfExists($t, "Finish")
            _ClickIfExists($t, "&Finish")
            _ClickIfExists($t, "Close")
            _ClickIfExists($t, "&Close")
        EndIf
    Next

    Return Not ProcessExists($pid)
EndFunc

Func _TickAllCheckboxes($title)
    ; Dò tối đa 30 control Button (checkbox/radio) và Check hết
    For $idx = 1 To 30
        Local $h = ControlGetHandle($title, "", "[CLASS:Button; INSTANCE:" & $idx & "]")
        If @error Or $h = "" Then ContinueLoop
        Local $chk = ControlCommand($title, "", $h, "IsChecked", "")
        If @error Then ContinueLoop
        If $chk = 0 Then
            ControlCommand($title, "", $h, "Check", "")
            Sleep(80)
        EndIf
    Next
EndFunc

Func _ClickIfExists($title, $controlOrText)
    ; Thử click theo text trực tiếp
    If ControlCommand($title, "", $controlOrText, "IsVisible", "") Then
        ControlClick($title, "", $controlOrText)
        Sleep(120)
        Return
    EndIf
    ; Duyệt tất cả Button để tìm text chứa chuỗi mong muốn
    Local $needle = StringLower($controlOrText)
    For $i = 1 To 40
        Local $h = ControlGetHandle($title, "", "[CLASS:Button; INSTANCE:" & $i & "]")
        If @error Or $h = "" Then ContinueLoop
        Local $txt = ControlGetText($title, "", $h)
        If StringInStr(StringLower($txt), $needle) Then
            ControlClick($title, "", $h)
            Sleep(120)
            ExitLoop
        EndIf
    Next
EndFunc
