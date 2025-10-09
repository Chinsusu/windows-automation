; Script d? k�ch ho?t c?a s? Earnapp v� th?c hi?n chu?i actions: Click Accept -> Invite -> Close_App -> Note -> Choose_Note -> Minimize
; Updated: Bu?c 3 s? d?ng WinClose thay v� t�m v� click Close_App.bmp (d�ng c?a s? gracefully, kh�ng kill process)
#include <MsgBoxConstants.au3>

; �u?ng d?n tuong d?i
#include "ImageSearchEx_UDF\ImageSearchEx_UDF.au3"

; Log file
Global $LOG_FILE = @TempDir & "\click_sequence_debug.log"
FileDelete($LOG_FILE)

Func _Log($msg)
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $line = $timestamp & " | " & $msg & @CRLF
    ConsoleWrite($line)
    FileWrite($LOG_FILE, $line)
EndFunc

_Log("[Click_Sequence] ==================== START ====================")
_Log("[Click_Sequence] Script directory: " & @ScriptDir)
_Log("[Click_Sequence] Log file: " & $LOG_FILE)

; Kh?i t?o UDF
_Log("[Click_Sequence] Initializing ImageSearchEx...")
_ImageSearchEx_Startup()
If @error Then
    _Log("[Click_Sequence] ERROR: Cannot load ImageSearchEx DLL - Error: " & @error)
    Exit 1
EndIf
_Log("[Click_Sequence] ImageSearchEx loaded successfully")

; H�m ch? c?a s? Earnapp xu?t hi?n
Func WaitForEarnappWindow($iTimeout = 30)
    _Log("[Click_Sequence] Waiting for Earnapp window (timeout: " & $iTimeout & "s)...")
    Local $hWnd = WinWait("[TITLE:Earnapp]", "", $iTimeout)
    If $hWnd Then
        _Log("[Click_Sequence] Found Earnapp window: HWND=" & $hWnd)
        WinActivate($hWnd)
        Sleep(500)
        Local $activated = WinWaitActive($hWnd, "", 5)
        If $activated Then
            _Log("[Click_Sequence] Window activated successfully")
        Else
            _Log("[Click_Sequence] WARNING: Window activation may have failed")
        EndIf
        Return True
    Else
        _Log("[Click_Sequence] ERROR: Earnapp window not found after " & $iTimeout & " seconds")
        Return False
    EndIf
EndFunc

; H�m ch? image xu?t hi?n trong c?a s? (ch? window)
Func WaitForImageInWindow($sImagePath, $aPos, $iTimeout = 30, $iTolerance = 100)
    _Log("[Click_Sequence] Waiting for image '" & $sImagePath & "' in window (timeout: " & $iTimeout & "s, tolerance: " & $iTolerance & ")...")
    Local $iStartTime = TimerInit()
    Local $iAttempts = 0
    While TimerDiff($iStartTime) < ($iTimeout * 1000)
        $iAttempts += 1
        _Log("[Click_Sequence] Search attempt " & $iAttempts & "...")
        Local $aResult = _ImageSearchEx_Area($sImagePath, $aPos[0], $aPos[1], $aPos[0] + $aPos[2], $aPos[1] + $aPos[3], $iTolerance)
        If Not @error And $aResult[0][0] > 0 Then
            Local $iX = $aResult[1][1]
            Local $iY = $aResult[1][2]
            _Log("[Click_Sequence] SUCCESS! Found image at X=" & $iX & " Y=" & $iY)
            Return $aResult
        EndIf
        Sleep(1000)
    WEnd
    _Log("[Click_Sequence] ERROR: Image not found after " & $iTimeout & " seconds (" & $iAttempts & " attempts)")
    Return 0
EndFunc

; H�m click v�o v? tr� (t? ImageSearch result)
Func ClickImage($aResult, $sActionName)
    If $aResult <> 0 Then
        Local $iX = $aResult[1][1]
        Local $iY = $aResult[1][2]
        _Log("[Click_Sequence] Moving mouse to " & $iX & "," & $iY & " for " & $sActionName)
        MouseMove($iX, $iY, 5)
        Sleep(1000)  ; Ch? hover
        MouseClick("left", $iX, $iY, 1, 10)  ; Click ch?m
        _Log("[Click_Sequence] Clicked " & $sActionName & " at (" & $iX & ", " & $iY & ")")
        Sleep(2000)  ; Ch? UI respond
        Return True
    Else
        _Log("[Click_Sequence] ERROR: Cannot click " & $sActionName & " - image not found")
        Return False
    EndIf
EndFunc

; H�m fallback click center window
Func ClickCenterFallback($aPos, $sActionName)
    Local $iX = $aPos[0] + $aPos[2] / 2
    Local $iY = $aPos[1] + $aPos[3] / 2
    MouseMove($iX, $iY, 5)
    Sleep(1000)
    MouseClick("left", $iX, $iY, 1, 10)
    _Log("[Click_Sequence] Clicked " & $sActionName & " (Fallback: Center at " & $iX & "," & $iY & ")")
    Sleep(2000)
    Return True
EndFunc

; Ch? v� k�ch ho?t c?a s?
If WaitForEarnappWindow(30) Then
    ; L?y v? tr� v� k�ch thu?c c?a s?
    _Log("[Click_Sequence] Getting window position...")
    Local $aPos = WinGetPos("Earnapp")
    If @error Then
        _Log("[Click_Sequence] ERROR: Cannot get window position - Error: " & @error)
        Exit 1
    EndIf

    _Log("[Click_Sequence] Window position: X=" & $aPos[0] & " Y=" & $aPos[1] & " W=" & $aPos[2] & " H=" & $aPos[3])

    ; Bu?c 1: T�m v� click Accept.bmp
    Local $sImagePath = @ScriptDir & "\Image\Accept.bmp"
    _Log("[Click_Sequence] Step 1: Image path for Accept: " & $sImagePath)
    If Not FileExists($sImagePath) Then
        _Log("[Click_Sequence] ERROR: Accept.bmp NOT found!")
        Exit 1
    EndIf
    Local $aResult = WaitForImageInWindow($sImagePath, $aPos, 60, 100)
    If $aResult <> 0 Then
        ClickImage($aResult, "Accept")
    Else
        ClickCenterFallback($aPos, "Accept")
    EndIf

    Sleep(5000)  ; Ch? sau Accept

    ; Bu?c 2: T�m Invite.bmp (ch? t�m, kh�ng click, continue n?u fail)
    $sImagePath = @ScriptDir & "\Image\Invite.bmp"
    _Log("[Click_Sequence] Step 2: Image path for Invite: " & $sImagePath)
    If FileExists($sImagePath) Then
        $aResult = WaitForImageInWindow($sImagePath, $aPos, 10, 100)  ; Gi?m timeout 10s
        If $aResult <> 0 Then
            _Log("[Click_Sequence] Found Invite")
        Else
            _Log("[Click_Sequence] WARNING: Invite not found, continuing anyway")
        EndIf
    Else
        _Log("[Click_Sequence] WARNING: Invite.bmp not found, skipping check")
    EndIf

    Sleep(3000)  ; Ch? sau Invite check

    ; Bu?c 3: ��ng giao di?n b?ng WinClose (thay v� t�m v� click Close_App.bmp)
    _Log("[Click_Sequence] Step 3: Closing Earnapp window using WinClose...")
    Local $bClosed = WinClose("Earnapp")
    If $bClosed Then
        _Log("[Click_Sequence] Successfully closed Earnapp window")
        ; Ch? c?a s? d�ng ho�n to�n
        WinWaitClose("Earnapp", "", 10)
        _Log("[Click_Sequence] Window closed confirmed")
    Else
        _Log("[Click_Sequence] WARNING: WinClose failed, trying Alt+F4 fallback...")
        ; Fallback: Send Alt+F4 to window
        WinActivate("Earnapp")
        Sleep(500)
        Send("!{F4}")
        Sleep(2000)
        If WinExists("Earnapp") Then
            _Log("[Click_Sequence] Alt+F4 fallback: Window still exists, may need manual intervention")
        Else
            _Log("[Click_Sequence] Alt+F4 fallback successful")
        EndIf
    EndIf

    Sleep(3000)

    ; Luu �: C�c bu?c sau (Note, Choose_Note, Minimize) c� th? fail n?u c?a s? d� d�ng
    ; N?u c?n ti?p t?c v?i c?a s? kh�c, di?u ch?nh logic ? d�y
    ; Bu?c 4: T�m Note.bmp (ch? t�m, nhung c� th? fail n?u window closed)
    $sImagePath = @ScriptDir & "\Image\Note.bmp"
    _Log("[Click_Sequence] Step 4: Image path for Note: " & $sImagePath)
    If FileExists($sImagePath) And WinExists("Earnapp") Then
        $aResult = WaitForImageInWindow($sImagePath, $aPos, 10, 100)
        If $aResult <> 0 Then
            _Log("[Click_Sequence] Found Note")
        Else
            _Log("[Click_Sequence] WARNING: Note not found")
        EndIf
    Else
        _Log("[Click_Sequence] Skipping Note check (window closed or file missing)")
    EndIf

    Sleep(3000)

    ; Bu?c 5: T�m v� click Choose_Note.bmp (n?u window still open)
    $sImagePath = @ScriptDir & "\Image\Choose_Note.bmp"
    _Log("[Click_Sequence] Step 5: Image path for Choose_Note: " & $sImagePath)
    If FileExists($sImagePath) And WinExists("Earnapp") Then
        $aResult = WaitForImageInWindow($sImagePath, $aPos, 30, 100)
        If $aResult <> 0 Then
            ClickImage($aResult, "Choose_Note")
        Else
            ; Fallback middle-left
            Local $iX = $aPos[0] + 100
            Local $iY = $aPos[1] + $aPos[3] / 2
            MouseMove($iX, $iY, 5)
            Sleep(1000)
            MouseClick("left", $iX, $iY, 1, 10)
            _Log("[Click_Sequence] Clicked Choose_Note (Fallback: Middle-left)")
            Sleep(2000)
        EndIf
    Else
        _Log("[Click_Sequence] Skipping Choose_Note (window closed or file missing)")
    EndIf

    Sleep(2000)

    ; Bu?c 6: T�m v� click Minimize.bmp (n?u window still open)
    $sImagePath = @ScriptDir & "\Image\Minimize.bmp"
    _Log("[Click_Sequence] Step 6: Image path for Minimize: " & $sImagePath)
    If FileExists($sImagePath) And WinExists("Earnapp") Then
        $aResult = WaitForImageInWindow($sImagePath, $aPos, 30, 100)
        If $aResult <> 0 Then
            ClickImage($aResult, "Minimize")
        Else
            ; Fallback title bar minimize
            Local $iX = $aPos[0] + $aPos[2] / 2 - 50
            Local $iY = $aPos[1] + 10
            MouseMove($iX, $iY, 5)
            Sleep(1000)
            MouseClick("left", $iX, $iY, 1, 10)
            _Log("[Click_Sequence] Clicked Minimize (Fallback: Title bar)")
            Sleep(2000)
        EndIf
    Else
        _Log("[Click_Sequence] Skipping Minimize (window closed or file missing)")
    EndIf

    _Log("[Click_Sequence] All steps completed successfully!")
Else
    _Log("[Click_Sequence] FATAL: Cannot find Earnapp window")
    Exit 1
EndIf

; Cleanup
_ImageSearchEx_Shutdown()
_Log("[Click_Sequence] ==================== END ====================")
_Log("[Click_Sequence] Log saved to: " & $LOG_FILE)