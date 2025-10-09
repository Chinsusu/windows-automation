; Script don gi?n d? l?y IP public t? icanhazip.com
; Ch?y script s? hi?n th? IP public trong MsgBox và log vào file

#include <WinHttp.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>

; Configuration
Global $sPublicIPURL = "http://icanhazip.com"
Global $LOG_FILE = @ScriptDir & "\public_ip.log"  ; Log file ? thu m?c script

; Function to get public IP
Func GetPublicIP()
    Local $hOpen = _WinHttpOpen()
    If @error Then
        MsgBox($MB_OK, "L?i", "Không th? m? k?t n?i WinHttp. Ki?m tra AutoIt version.")
        Return ""
    EndIf

    Local $hConnect = _WinHttpConnect($hOpen, "icanhazip.com")
    If @error Then
        _WinHttpCloseHandle($hOpen)
        MsgBox($MB_OK, "L?i", "Không th? k?t n?i d?n icanhazip.com.")
        Return ""
    EndIf

    Local $hRequest = _WinHttpSimpleSendRequest($hConnect, "GET")
    _WinHttpReceiveResponse($hRequest)
    Local $sPublicIP = ""
    If _WinHttpQueryDataAvailable($hRequest) Then
        $sPublicIP = _WinHttpReadData($hRequest)
        $sPublicIP = StringStripWS($sPublicIP, 3)  ; Trim whitespace
    EndIf

    _WinHttpCloseHandle($hRequest)
    _WinHttpCloseHandle($hConnect)
    _WinHttpCloseHandle($hOpen)

    ; Log to file
    If $sPublicIP <> "" Then
        Local $sLog = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " | Public IP: " & $sPublicIP
        FileWriteLine($LOG_FILE, $sLog)
    EndIf

    Return $sPublicIP
EndFunc

; Main
Local $sPublicIP = GetPublicIP()
If $sPublicIP <> "" Then
    MsgBox($MB_OK, "Public IP", "IP Public c?a b?n: " & $sPublicIP & @CRLF & "Log luu t?i: " & $LOG_FILE)
Else
    MsgBox($MB_OK, "L?i", "Không l?y du?c IP Public. Ki?m tra k?t n?i m?ng.")
EndIf