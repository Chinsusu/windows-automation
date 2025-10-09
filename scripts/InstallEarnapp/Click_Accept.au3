; Script d? kích ho?t c?a s? Earnapp và th?c hi?n chu?i actions: Click Accept -> Invite -> Close_App -> Note -> Choose_Note -> Minimize
#include <MsgBoxConstants.au3>

; Ðu?ng d?n tuong d?i
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

; Hàm ch? c?a s? Earnapp xu?t hi?n
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

; Hàm ch? image xu?t hi?n trong c?a s? (loop search) và tr? v? v? trí n?u tìm th?y
Func WaitForImageInWindow($sImagePath, $aPos, $iTimeout = 30, $iTolerance = 100)  ; Tang tolerance m?c d?nh lên 100
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
            Return $aResult  ; Tr? v? k?t qu? d? l?y v? trí
        EndIf
        Sleep(1000)  ; Ch? 1 giây tru?c khi search l?i
    WEnd
    _Log("[Click_Sequence] ERROR: Image not found after " & $iTimeout & " seconds (" & $iAttempts & " attempts)")
    Return 0
EndFunc

; Hàm ch? image xu?t hi?n toàn màn hình (loop search) và tr? v? v? trí n?u tìm th?y
Func WaitForImageFullScreen($sImagePath, $iTimeout = 30, $iTolerance = 100)
    _Log("[Click_Sequence] Waiting for image '" & $sImagePath & "' FULL SCREEN (timeout: " & $iTimeout & "s, tolerance: " & $iTolerance & ")...")
    Local $iStartTime = TimerInit()
    Local $iAttempts = 0
    While TimerDiff($iStartTime) < ($iTimeout * 1000)
        $iAttempts += 1
        _Log("[Click_Sequence] Full screen search attempt " & $iAttempts & "...")
        Local $aResult = _ImageSearchEx_Area($sImagePath, 0, 0, @DesktopWidth, @DesktopHeight, $iTolerance)
        If Not @error And $aResult[0][0] > 0 Then
            Local $iX = $aResult[1][1]
            Local $iY = $aResult[1][2]
            _Log("[Click_Sequence] SUCCESS! Found image full screen at X=" & $iX & " Y=" & $iY)
            Return $aResult  ; Tr? v? k?t qu? d? l?y v? trí
        EndIf
        Sleep(1000)  ; Ch? 1 giây tru?c khi search l?i
    WEnd
    _Log("[Click_Sequence] ERROR: Image not found full screen after " & $iTimeout & " seconds (" & $iAttempts & " attempts)")
    Return 0
EndFunc

; Hàm click vào v? trí image
Func ClickImage($aResult, $sActionName)
    If $aResult <> 0 Then
        Local $iX = $aResult[1][1]
        Local $iY = $aResult[1][2]
        MouseMove($iX, $iY, 5)
        Sleep(500)
        MouseClick("left", $iX, $iY, 1, 5)
        _Log("[Click_Sequence] Clicked " & $sActionName)
        Return True
    Else
        _Log("[Click_Sequence] ERROR: Cannot click " & $sActionName & " - image not found")
        Return False
    EndIf
EndFunc

; Ch? và kích ho?t c?a s?
If WaitForEarnappWindow(30) Then
    ; L?y v? trí và kích thu?c c?a s?
    _Log("[Click_Sequence] Getting window position...")
    Local $aPos = WinGetPos("Earnapp")
    If @error Then
        _Log("[Click_Sequence] ERROR: Cannot get window position - Error: " & @error)
        Exit 1
    EndIf

    _Log("[Click_Sequence] Window position: X=" & $aPos[0] & " Y=" & $aPos[1] & " W=" & $aPos[2] & " H=" & $aPos[3])

    ; Bu?c 1: Tìm và click Accept.bmp (tang timeout và tolerance)
    Local $sImagePath = @ScriptDir & "\Image\Accept.bmp"
    _Log("[Click_Sequence] Step 1: Image path for Accept: " & $sImagePath)
    If Not FileExists($sImagePath) Then
        _Log("[Click_Sequence] ERROR: Accept.bmp NOT found!")
        Exit 1
    EndIf
    Local $aResult = WaitForImageInWindow($sImagePath, $aPos, 60, 100)  ; Tang timeout 60s, tolerance 100
    If $aResult = 0 Then
        _Log("[Click_Sequence] Fallback for Accept: Click center of window")
        Local $iX = $aPos[0] + $aPos[2] / 2
        Local $iY = $aPos[1] + $aPos[3] / 2
        MouseMove($iX, $iY, 5)
        Sleep(500)
        MouseClick("left", $iX, $iY, 1, 5)
        _Log("[Click_Sequence] Clicked Accept (Fallback: Center)")
    Else
        If Not ClickImage($aResult, "Accept") Then Exit 1
    EndIf

    Sleep(3000)  ; Tang ch? sau click Accept d? UI update

    ; Bu?c 2: Tìm Invite.bmp (ch? tìm, không click, d? confirm xu?t hi?n)
    $sImagePath = @ScriptDir & "\Image\Invite.bmp"
    _Log("[Click_Sequence] Step 2: Image path for Invite: " & $sImagePath)
    If Not FileExists($sImagePath) Then
        _Log("[Click_Sequence] ERROR: Invite.bmp NOT found!")
        Exit 1
    EndIf
    $aResult = WaitForImageInWindow($sImagePath, $aPos, 30, 100)
    If $aResult = 0 Then
        _Log("[Click_Sequence] WARNING: Invite not found, continuing...")
    EndIf

    Sleep(2000)  ; Ch? sau khi tìm th?y Invite (ho?c skip)

    ; Bu?c 3: Tìm và click Close_App.bmp
    $sImagePath = @ScriptDir & "\Image\Close_App.bmp"
    _Log("[Click_Sequence] Step 3: Image path for Close_App: " & $sImagePath)
    If Not FileExists($sImagePath) Then
        _Log("[Click_Sequence] ERROR: Close_App.bmp NOT found!")
        Exit 1
    EndIf
    $aResult = WaitForImageInWindow($sImagePath, $aPos, 30, 100)
    If $aResult = 0 Then
        _Log("[Click_Sequence] Fallback for Close_App: Click top-right corner")
        Local $iX = $aPos[0] + $aPos[2] - 20
        Local $iY = $aPos[1] + 10
        MouseMove($iX, $iY, 5)
        Sleep(500)
        MouseClick("left", $iX, $iY, 1, 5)
        _Log("[Click_Sequence] Clicked Close_App (Fallback: Top-right)")
    Else
        If Not ClickImage($aResult, "Close_App") Then Exit 1
    EndIf

    Sleep(3000)  ; Ch? sau click Close_App

    ; Bu?c 4: Tìm và activate CloseWindowPopup
    _Log("[Click_Sequence] Step 4: Waiting for CloseWindowPopup window...")
    Local $hPopup = WinWait("[TITLE:CloseWindowPopup]", "", 30)
    If $hPopup Then
        _Log("[Click_Sequence] Found CloseWindowPopup window: HWND=" & $hPopup)
        WinActivate($hPopup)
        Sleep(500)
        Local $activated = WinWaitActive($hPopup, "", 5)
        If $activated Then
            _Log("[Click_Sequence] CloseWindowPopup activated successfully")
        Else
            _Log("[Click_Sequence] WARNING: CloseWindowPopup activation may have failed")
        EndIf
        ; L?y v? trí và kích thu?c popup
        Local $aPopupPos = WinGetPos($hPopup)
        If @error Then
            _Log("[Click_Sequence] ERROR: Cannot get popup position - Error: " & @error)
            Exit 1
        EndIf
        _Log("[Click_Sequence] Popup position: X=" & $aPopupPos[0] & " Y=" & $aPopupPos[1] & " W=" & $aPopupPos[2] & " H=" & $aPopupPos[3])
    Else
        _Log("[Click_Sequence] ERROR: CloseWindowPopup window not found after 30 seconds")
        Exit 1
    EndIf

    Sleep(2000)  ; Ch? sau khi activate popup

    ; Bu?c 5: Tìm và click Choose_Note.bmp trong ph?m vi popup
    $sImagePath = @ScriptDir & "\Image\Choose_Note.bmp"
    _Log("[Click_Sequence] Step 5: Image path for Choose_Note: " & $sImagePath)
    If Not FileExists($sImagePath) Then
        _Log("[Click_Sequence] ERROR: Choose_Note.bmp NOT found!")
        Exit 1
    EndIf
    $aResult = WaitForImageInWindow($sImagePath, $aPopupPos, 30, 100)
    If $aResult = 0 Then
        _Log("[Click_Sequence] Fallback for Choose_Note: Click middle-left of popup")
        Local $iX = $aPopupPos[0] + 100
        Local $iY = $aPopupPos[1] + $aPopupPos[3] / 2
        MouseMove($iX, $iY, 5)
        Sleep(500)
        MouseClick("left", $iX, $iY, 1, 5)
        _Log("[Click_Sequence] Clicked Choose_Note (Fallback: Middle-left of popup)")
    Else
        If Not ClickImage($aResult, "Choose_Note") Then Exit 1
    EndIf

    Sleep(2000)  ; Ch? sau click Choose_Note

    ; Bu?c 6: Tìm và click Minimize.bmp trong ph?m vi popup
    $sImagePath = @ScriptDir & "\Image\Minimize.bmp"
    _Log("[Click_Sequence] Step 6: Image path for Minimize: " & $sImagePath)
    If Not FileExists($sImagePath) Then
        _Log("[Click_Sequence] ERROR: Minimize.bmp NOT found!")
        Exit 1
    EndIf
    $aResult = WaitForImageInWindow($sImagePath, $aPopupPos, 30, 100)
    If $aResult = 0 Then
        _Log("[Click_Sequence] Fallback for Minimize: Click minimize button position in popup")
        Local $iX = $aPopupPos[0] + $aPopupPos[2] / 2 - 50  ; Gi? d?nh v? trí minimize bar
        Local $iY = $aPopupPos[1] + 10
        MouseMove($iX, $iY, 5)
        Sleep(500)
        MouseClick("left", $iX, $iY, 1, 5)
        _Log("[Click_Sequence] Clicked Minimize (Fallback: Title bar in popup)")
    Else
        If Not ClickImage($aResult, "Minimize") Then Exit 1
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