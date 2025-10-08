; Script để kích hoạt cửa sổ Earnapp và tìm nút SKIP bằng ImageSearchEx
#include <MsgBoxConstants.au3>

; Đường dẫn tương đối
#include "ImageSearchEx_UDF\ImageSearchEx_UDF.au3"

; Log file
Global $LOG_FILE = @TempDir & "\click_skip_debug.log"
FileDelete($LOG_FILE)

Func _Log($msg)
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $line = $timestamp & " | " & $msg & @CRLF
    ConsoleWrite($line)
    FileWrite($LOG_FILE, $line)
EndFunc

_Log("[Click_Skip] ==================== START ====================")
_Log("[Click_Skip] Script directory: " & @ScriptDir)
_Log("[Click_Skip] Log file: " & $LOG_FILE)

; Khởi tạo UDF
_Log("[Click_Skip] Initializing ImageSearchEx...")
_ImageSearchEx_Startup()
If @error Then
    _Log("[Click_Skip] ERROR: Cannot load ImageSearchEx DLL - Error: " & @error)
    Exit 1
EndIf
_Log("[Click_Skip] ImageSearchEx loaded successfully")

; Hàm chờ cửa sổ Earnapp xuất hiện
Func WaitForEarnappWindow($iTimeout = 30)
    _Log("[Click_Skip] Waiting for Earnapp window (timeout: " & $iTimeout & "s)...")
    Local $hWnd = WinWait("[TITLE:Earnapp]", "", $iTimeout)
    If $hWnd Then
        _Log("[Click_Skip] Found Earnapp window: HWND=" & $hWnd)
        WinActivate($hWnd)
        Sleep(500)
        Local $activated = WinWaitActive($hWnd, "", 5)
        If $activated Then
            _Log("[Click_Skip] Window activated successfully")
        Else
            _Log("[Click_Skip] WARNING: Window activation may have failed")
        EndIf
        Return True
    Else
        _Log("[Click_Skip] ERROR: Earnapp window not found after " & $iTimeout & " seconds")
        Return False
    EndIf
EndFunc

; Chờ và kích hoạt cửa sổ
If WaitForEarnappWindow(30) Then
    ; Lấy vị trí và kích thước cửa sổ
    _Log("[Click_Skip] Getting window position...")
    Local $aPos = WinGetPos("Earnapp")
    If @error Then
        _Log("[Click_Skip] ERROR: Cannot get window position - Error: " & @error)
        Exit 1
    EndIf
    
    _Log("[Click_Skip] Window position: X=" & $aPos[0] & " Y=" & $aPos[1] & " W=" & $aPos[2] & " H=" & $aPos[3])
    
    ; Đường dẫn hình ảnh SKIP
    Local $sImagePath = @ScriptDir & "\Image\skip.bmp"
    _Log("[Click_Skip] Image path: " & $sImagePath)
    
    If Not FileExists($sImagePath) Then
        _Log("[Click_Skip] ERROR: Image file NOT found!")
    Else
        _Log("[Click_Skip] Image file exists")
    EndIf

    ; METHOD 1: ImageSearch
    _Log("[Click_Skip] METHOD 1: ImageSearch (tolerance=50)...")
    Local $aResult = _ImageSearchEx_Area($sImagePath, $aPos[0], $aPos[1], $aPos[0] + $aPos[2], $aPos[1] + $aPos[3], 50)
    
    If @error Then
        _Log("[Click_Skip] ImageSearch ERROR: " & @error)
    EndIf

    If $aResult[0][0] > 0 Then
        ; Lấy vị trí trung tâm của match đầu tiên
        Local $iX = $aResult[1][1]
        Local $iY = $aResult[1][2]

        _Log("[Click_Skip] SUCCESS! Found Skip at X=" & $iX & " Y=" & $iY)
        
        ; Di chuyển chuột và click
        MouseMove($iX, $iY, 5)
        Sleep(500)
        MouseClick("left", $iX, $iY, 1, 5)
        _Log("[Click_Skip] Clicked (ImageSearch)")
    Else
        _Log("[Click_Skip] ImageSearch: No match, trying PixelSearch...")
        
        ; METHOD 2: PixelSearch
        Local $aPixelResult = PixelSearch($aPos[0], $aPos[1], $aPos[0] + $aPos[2], $aPos[1] + $aPos[3], 0x140932, 30)
        If Not @error Then
            _Log("[Click_Skip] SUCCESS! Found Skip via PixelSearch at X=" & $aPixelResult[0] & " Y=" & $aPixelResult[1])
            
            MouseMove($aPixelResult[0], $aPixelResult[1], 5)
            Sleep(500)
            MouseClick("left", $aPixelResult[0], $aPixelResult[1], 1, 5)
            _Log("[Click_Skip] Clicked (PixelSearch)")
        Else
            _Log("[Click_Skip] PixelSearch failed, using fallback...")
            
            ; METHOD 3: Fallback position
            Local $iX = $aPos[0] + $aPos[2] - 80  ; Cách mép phải 80px
            Local $iY = $aPos[1] + 70             ; Cách top 70px
            
            _Log("[Click_Skip] Fallback position: X=" & $iX & " Y=" & $iY)
            
            MouseMove($iX, $iY, 5)
            Sleep(500)
            MouseClick("left", $iX, $iY, 1, 5)
            _Log("[Click_Skip] Clicked (Fallback)")
        EndIf
    EndIf
Else
    _Log("[Click_Skip] FATAL: Cannot find Earnapp window")
    Exit 1
EndIf

; Cleanup
_ImageSearchEx_Shutdown()
_Log("[Click_Skip] ==================== END ====================")
_Log("[Click_Skip] Log saved to: " & $LOG_FILE)
