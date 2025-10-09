#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#pragma compile(x64, true)
#cs ----------------------------------------------------------------------------
	;
	;    Title .........: ImageSearchEx Automation Suite (Enhanced with File Browser)
	;    AutoIt Version : 3.3.16.1
	;    Author ........: Dao Van Trong (TRONG.PRO)
	;    Date ..........: 2025-09-15
	;    Note ..........: This script is a graphical user interface (GUI) front-end for the
	;                     ImageSearchEx_UDF.au3 and its underlying ImageSearchEx.dll.
	;                     It allows for visual configuration of image search tasks on the screen
	;                     or within another image file, and now includes a file browser for
	;                     selecting existing images.
	;
	; -------------------------------------------------------------------------------------------------------------------------------
	; #SECTION# SCRIPT OVERVIEW
	; -------------------------------------------------------------------------------------------------------------------------------
	;
	; This enhanced script provides a powerful and user-friendly interface for performing complex image search and automation tasks.
	; It acts as a control panel for the high-performance ImageSearchEx UDF, allowing you to visually configure, execute,
	; and log search operations without writing complex code. It supports searching images on the screen or within another image.
	; NEW: Added "Browse" buttons to select existing image files instead of only capturing from screen.
	;
	; -------------------------------------------------------------------------------------------------------------------------------
	; #SECTION# FIRST-TIME SETUP
	; -------------------------------------------------------------------------------------------------------------------------------
	;
	; Before you can start a search, you need to provide the images you want to find.
	;
	; 1. RUN THE SCRIPT: The main window will appear. On the right side, you will see 12 empty "Image Target" slots.
	;
	; 2. CREATE OR SELECT AN IMAGE:
	;    - Click the "Create" button next to slot #1 to capture a region from the screen.
	;    - OR click the "Browse" button next to slot #1 to select an existing image file.
	;
	; 3. FOR CREATE: The script window will hide. Your mouse cursor will turn into a crosshair.
	;    Click and drag a rectangle around the object on the screen you want to find. When you release the mouse button,
	;    a bitmap image named "Search_1.bmp" will be saved in the same directory as the script.
	;
	; 4. FOR BROWSE: A file dialog will open allowing you to select BMP, JPG, PNG, or other image files.
	;    The selected image will be copied to the script directory as "Search_X.bmp".
	;
	; 5. PREVIEW UPDATES: The image you just captured/selected will now appear in the preview panel for that slot.
	;
	; 6. REPEAT: Repeat this process for any other images you need to find (up to 12).
	;
	; 7. IMAGE-IN-IMAGE SEARCH: To search within an image, select "Search in Image" mode, then specify a source image file
	;    using the "Browse Source Image" button.
	;
#ce ----------------------------------------------------------------------------

; === INCLUDES ===
#include <Array.au3>
#include <GDIPlus.au3>
#include <ScreenCapture.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <Date.au3>
#include <Misc.au3>
#include <Math.au3>
#include <GuiEdit.au3>
#include <GuiStatusBar.au3>
#include <File.au3>
#include "ImageSearchEx_UDF.au3" ; Core image search functionality

; === GLOBAL CONSTANTS ===
Global Const $MAX_IMAGES = 12 ; Maximum number of image targets the GUI supports.
Global Const $g_sPlaceholderPath = @WindowsDir & "\Web\Wallpaper\Windows\img0.jpg" ; Default image to show in empty slots.

; === GLOBAL VARIABLES ===
Global $g_asImagePaths[$MAX_IMAGES] ; Array to store the file paths for the 12 target images.
Global $g_nMsg ; Stores the message code from GUIGetMsg() for the main event loop.
Global $g_hMainGUI ; Handle for the main GUI window.
Global $g_hLog ; Handle for the activity log Edit control.
Global $g_hStatusBar ; Handle for the status bar at the bottom of the GUI.

; --- GUI Control IDs ---
Global $g_idBtnStart, $g_idBtnSelectAll, $g_idBtnDeselectAll, $g_idBtnSelectArea
Global $g_idInputDelay, $g_idChkMoveMouse
Global $g_idRadNoClick, $g_idRadSingleClick, $g_idRadDoubleClick
Global $g_idChkWait, $g_idInputWaitTime
Global $g_idChkUseArea, $g_idInputLeft, $g_idInputTop, $g_idInputRight, $g_idInputBottom
Global $g_idChkMultiSearch, $g_idChkFindAll, $g_idChkUseTolerance, $g_idInputTolerance, $g_idChkEnableDebug
Global $g_aidPic[$MAX_IMAGES], $g_aidChkSearch[$MAX_IMAGES], $g_aidBtnCreate[$MAX_IMAGES], $g_aidBtnBrowse[$MAX_IMAGES]
Global $g_idRadSearchOnScreen, $g_idRadSearchInImage, $g_idInputSourceImage, $g_idBtnBrowseSource

_Main()

; #FUNCTION# ====================================================================================================================
; Name...........: _Main
; Description....: Main program entry point. Initializes all necessary components and enters the GUI message loop to handle user interactions.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _Main()
	; Explicitly initialize the ImageSearchEx library. This is a critical first step.
	If Not _ImageSearchEx_Startup() Then
		MsgBox(16, "Fatal Error", "Failed to initialize the ImageSearchEx DLL. @error: " & @error & @CRLF & "The script will now exit.")
		Exit
	EndIf

	; Start GDI+ for image processing and create the GUI
	_GDIPlus_Startup()
	_InitializeImagePaths()
	_CreateGUI()
	_UpdateAllImagePreviews()
	_RefreshImageTooltips()

	; Main event loop to handle GUI events. The script will wait here for user input.
	While 1
		$g_nMsg = GUIGetMsg()
		Switch $g_nMsg
			Case $GUI_EVENT_CLOSE
				ExitLoop ; Exit the loop and terminate the script.

			Case $g_idBtnStart
				_StartSearch() ; Begin the image search process.

			Case $g_idBtnSelectAll
				_SelectAll(True) ; Check all image target checkboxes.

			Case $g_idBtnDeselectAll
				_SelectAll(False) ; Uncheck all image target checkboxes.

			Case $g_idBtnSelectArea
				_SelectAreaOnScreen() ; Allow user to define a search area on the screen.

			Case $g_idBtnBrowseSource
				_BrowseSourceImage() ; Open file dialog to select the source image for image-in-image search.

				; Event handlers for the "Create" and "Browse" buttons for each image slot.
			Case $g_aidBtnCreate[0] To $g_aidBtnCreate[$MAX_IMAGES - 1]
				_HandleImageCreation($g_nMsg)

			Case $g_aidBtnBrowse[0] To $g_aidBtnBrowse[$MAX_IMAGES - 1]
				_HandleImageBrowse($g_nMsg)
		EndSwitch
	WEnd

	_Exit()
EndFunc   ;==>_Main

; #FUNCTION# ====================================================================================================================
; Name...........: _InitializeImagePaths
; Description....: Populates the global array '$g_asImagePaths' with default file paths for the search images (e.g., Search_1.bmp, Search_2.bmp).
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _InitializeImagePaths()
	For $i = 0 To $MAX_IMAGES - 1
		$g_asImagePaths[$i] = @ScriptDir & "\Search_" & $i + 1 & ".bmp"
	Next
EndFunc   ;==>_InitializeImagePaths

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateGUI
; Description....: Creates the entire graphical user interface, defining all controls, their positions, and initial states.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateGUI()
	$g_hMainGUI = GUICreate("ImageSearchEx Automation by Dao Van Trong - TRONG.PRO", 906, 681)
	GUISetFont(9, 400, 0, "Segoe UI", $g_hMainGUI, 5)

	; --- LEFT COLUMN: CONFIGURATION ---
	GUICtrlCreateGroup("Configuration", 10, 10, 390, 340)

	; --- Search Mode Group ---
	GUICtrlCreateGroup("Search Mode", 20, 30, 180, 224)
	$g_idRadSearchOnScreen = GUICtrlCreateRadio("Search on Screen", 30, 50, 160, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlSetTip(-1, "Search for images on the computer screen.")
	$g_idRadSearchInImage = GUICtrlCreateRadio("Search in Image", 30, 75, 160, 20)
	GUICtrlSetTip(-1, "Search for images within a specified source image file.")
	$g_idInputSourceImage = GUICtrlCreateInput("", 30, 100, 120, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	$g_idBtnBrowseSource = GUICtrlCreateButton("Browse", 150, 98, 45, 23)
	GUICtrlSetTip(-1, "Select the source image file to search within.")
	$g_idChkMultiSearch = GUICtrlCreateCheckbox("Multi Search (All at once)", 30, 125, 160, 20)
	GUICtrlSetTip(-1, "Searches for all selected images in a single operation." & @CRLF & "Finds the FIRST occurrence of ANY of the selected images.")
	$g_idChkFindAll = GUICtrlCreateCheckbox("Find All Occurrences", 30, 150, 160, 20)
	GUICtrlSetTip(-1, "Finds EVERY instance of the selected image(s), not just the first one.")
	$g_idChkWait = GUICtrlCreateCheckbox("Wait for Image Found", 30, 175, 160, 20)
	GUICtrlSetTip(-1, "Pauses the script until an image is found or the timeout is reached. (Screen search only)")
	$g_idChkUseTolerance = GUICtrlCreateCheckbox("Use Tolerance", 30, 200, 160, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlSetTip(-1, "Allows for slight variations between the target and found images. 0=exact match.")
	$g_idChkEnableDebug = GUICtrlCreateCheckbox("Enable DLL Debug", 30, 225, 160, 20)
	GUICtrlSetTip(-1, "Prints raw DLL output to the Activity Log for troubleshooting.")

	; --- Parameters Group ---
	GUICtrlCreateGroup("Parameters", 210, 30, 180, 94)
	GUICtrlCreateLabel("Timeout (ms):", 220, 50, 80, 20)
	$g_idInputWaitTime = GUICtrlCreateInput("5000", 300, 47, 80, 21)
	GUICtrlCreateLabel("Tolerance:", 220, 75, 80, 20)
	$g_idInputTolerance = GUICtrlCreateInput("10", 300, 72, 80, 21)
	GUICtrlCreateLabel("Delay (ms):", 220, 100, 80, 20)
	$g_idInputDelay = GUICtrlCreateInput("500", 300, 97, 80, 21)

	; --- Actions on Found Group ---
	GUICtrlCreateGroup("Actions on Found", 214, 134, 174, 122)
	$g_idChkMoveMouse = GUICtrlCreateCheckbox("Move Mouse", 224, 154, 100, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlSetTip(-1, "Move the mouse to the center of the found image. (Screen search only)")
	GUICtrlCreateLabel("Click:", 224, 179, 40, 20)
	$g_idRadNoClick = GUICtrlCreateRadio("None", 264, 179, 55, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	$g_idRadSingleClick = GUICtrlCreateRadio("Single", 224, 199, 60, 20)
	GUICtrlSetTip(-1, "Perform a single left-click. (Screen search only)")
	$g_idRadDoubleClick = GUICtrlCreateRadio("Double", 284, 199, 65, 20)
	GUICtrlSetTip(-1, "Perform a double left-click. (Screen search only)")

	; --- Search Area Group ---
	GUICtrlCreateGroup("Search Area", 16, 262, 372, 82)
	$g_idChkUseArea = GUICtrlCreateCheckbox("Use Custom Area", 27, 280, 134, 20)
	GUICtrlSetTip(-1, "Restrict the search to a specific rectangular area of the screen.")
	GUICtrlCreateLabel("Left:", 27, 313, 30, 20)
	$g_idInputLeft = GUICtrlCreateInput("0", 62, 310, 50, 23)
	GUICtrlCreateLabel("Top:", 122, 313, 30, 20)
	$g_idInputTop = GUICtrlCreateInput("0", 157, 310, 30, 23)
	GUICtrlCreateLabel("Right:", 195, 314, 35, 20)
	$g_idInputRight = GUICtrlCreateInput(@DesktopWidth, 230, 311, 50, 23)
	GUICtrlCreateLabel("Bottom:", 290, 314, 40, 20)
	$g_idInputBottom = GUICtrlCreateInput(@DesktopHeight, 340, 311, 40, 23)
	$g_idBtnSelectArea = GUICtrlCreateButton("Select Area on Screen", 183, 278, 195, 25)
	GUICtrlSetTip(-1, "Click and drag to visually select the search area. (Screen search only)")

	; --- RIGHT COLUMN: IMAGE TARGETS ---
	GUICtrlCreateGroup("Image Targets", 410, 6, 486, 494)
	Local $iPicWidth = 100, $iPicHeight = 100
	Local $iX_Start = 425, $iY_Start = 30
	Local $iColWidth = 118, $iRowHeight = 150

	_CreateCheckboxGrid($g_aidChkSearch, $MAX_IMAGES, $iX_Start-5, $iY_Start, $iColWidth, $iRowHeight)
	_CreateBtnCreateGrid($g_aidBtnCreate, $MAX_IMAGES, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	_CreateBtnBrowseGrid($g_aidBtnBrowse, $MAX_IMAGES, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	_CreatePicGrid($g_aidPic, $MAX_IMAGES, $iX_Start , $iY_Start+22, $iColWidth, $iRowHeight, $iPicWidth, $iPicHeight)

	; --- BOTTOM SECTION: LOGS & SYSTEM INFO ---
	GUICtrlCreateGroup("Activity Log", 13, 512, 880, 142)
	$g_hLog = GUICtrlCreateEdit("",18, 527, 862, 114, BitOR($ES_MULTILINE, $ES_READONLY, $WS_VSCROLL, $ES_AUTOVSCROLL))
	GUICtrlSetFont(-1, 9, 0, 0, "Segoe UI", 5)

	GUICtrlCreateGroup("System Information", 12, 395, 392, 104)
	GUICtrlCreateLabel("OS: " & @OSVersion & " (" & @OSArch & ")" & "   |   AutoIt: " & @AutoItVersion & (@AutoItX64 ? " (x64)" : ""), 28, 417, 360, 20)
	GUICtrlCreateLabel("ImageSearchEx DLL In Use: v" & $__ImageSearchEx_UDF_VERSION, 28, 442, 360, 20)
	GUICtrlCreateInput($g_sImageSearchExDLL_Path, 23, 469, 360, 23, BitOR($GUI_SS_DEFAULT_INPUT,$ES_READONLY))

	; --- MAIN ACTION BUTTONS ---
$g_idBtnStart = GUICtrlCreateButton("Start Search", 9, 358, 224, 32, $BS_DEFPUSHBUTTON)
	GUICtrlSetFont(-1, 14, 700, 0, "Segoe UI", 5)
$g_idBtnSelectAll = GUICtrlCreateButton("Select All", 247, 358, 75, 32)
$g_idBtnDeselectAll = GUICtrlCreateButton("Deselect All", 329, 358, 75, 32)

	; --- STATUS BAR ---
	$g_hStatusBar = _GUICtrlStatusBar_Create($g_hMainGUI)
	_UpdateStatus("Ready")

	GUISetState(@SW_SHOW)
	_UpdateSearchModeControls() ; Initial call to set control states correctly.
EndFunc   ;==>_CreateGUI


; #REGION# === GUI CREATION HELPER FUNCTIONS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _GetControlPos
; Description....: Calculates the X and Y coordinates for a control within a grid layout based on its index.
; Parameters.....: $iIndex     - The zero-based index of the control in the grid.
;                  $iX_Start   - The starting X coordinate of the grid.
;                  $iY_Start   - The starting Y coordinate of the grid.
;                  $iColWidth  - The width of each column.
;                  $iRowHeight - The height of each row.
;                  $iX         - [ByRef] Returns the calculated X coordinate.
;                  $iY         - [ByRef] Returns the calculated Y coordinate.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _GetControlPos($iIndex, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, ByRef $iX, ByRef $iY)
	$iX = $iX_Start + ($iColWidth * Mod($iIndex, 4)) ; 4 controls per row
	$iY = $iY_Start + ($iRowHeight * Int($iIndex / 4))
EndFunc   ;==>_GetControlPos

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateCheckboxGrid
; Description....: Creates a grid of checkboxes for selecting image targets.
; Parameters.....: $aStore     - [ByRef] An array to store the control IDs of the created checkboxes.
;                  $MAX        - The total number of checkboxes to create.
;                  ... Grid layout parameters ...
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateCheckboxGrid(ByRef $aStore, $MAX, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	Local $iX, $iY
	For $i = 0 To $MAX - 1
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aStore[$i] = GUICtrlCreateCheckbox("Img " & String($i + 1), $iX, $iY, 55, 20)
	Next
EndFunc   ;==>_CreateCheckboxGrid

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateBtnCreateGrid
; Description....: Creates a grid of "Create" buttons for capturing new images.
; Parameters.....: $aStore     - [ByRef] An array to store the control IDs of the created buttons.
;                  ... Other parameters are the same as _CreateCheckboxGrid ...
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateBtnCreateGrid(ByRef $aStore, $MAX, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	Local $iX, $iY
	For $i = 0 To $MAX - 1
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aStore[$i] = GUICtrlCreateButton("Create", $iX + 50, $iY - 2, 59, 22)
		GUICtrlSetTip(-1, "Capture screen area as image " & ($i + 1))
	Next
EndFunc   ;==>_CreateBtnCreateGrid

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateBtnBrowseGrid
; Description....: Creates a grid of "Browse" buttons for selecting existing image files.
; Parameters.....: $aStore     - [ByRef] An array to store the control IDs of the created buttons.
;                  ... Other parameters are the same as _CreateCheckboxGrid ...
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateBtnBrowseGrid(ByRef $aStore, $MAX, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	Local $iX, $iY
	For $i = 0 To $MAX - 1
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aStore[$i] = GUICtrlCreateButton("Browse", $iX + 50, $iY + 23, 59, 22)
		GUICtrlSetTip(-1, "Select an existing image file for slot " & ($i + 1))
	Next
EndFunc   ;==>_CreateBtnBrowseGrid

; #FUNCTION# ====================================================================================================================
; Name...........: _CreatePicGrid
; Description....: Creates a grid of Picture controls to display image previews.
; Parameters.....: $aStore     - [ByRef] An array to store the control IDs of the created Picture controls.
;                  ... Other parameters are the same as _CreateCheckboxGrid ...
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreatePicGrid(ByRef $aStore, $MAX, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iPicWidth, $iPicHeight)
	Local $iX, $iY
	For $i = 0 To $MAX - 1
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aStore[$i] = GUICtrlCreatePic("", $iX, $iY + 25, $iPicWidth, $iPicHeight, $SS_CENTERIMAGE)
	Next
EndFunc   ;==>_CreatePicGrid

#EndRegion ; === END GUI CREATION HELPER FUNCTIONS ===


; #REGION# === EVENT HANDLERS & GUI LOGIC ===

; #FUNCTION# ====================================================================================================================
; Name...........: _HandleImageBrowse
; Description....: Event handler for all "Browse" button clicks. It identifies which button was clicked and calls the file selection function.
; Parameters.....: $nMsg - The control ID of the pressed Browse button.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _HandleImageBrowse($nMsg)
	For $i = 0 To $MAX_IMAGES - 1
		If $nMsg = $g_aidBtnBrowse[$i] Then
			_BrowseImageFile($i)
			Return ; Exit the loop once the correct button is found and handled.
		EndIf
	Next
EndFunc   ;==>_HandleImageBrowse

; #FUNCTION# ====================================================================================================================
; Name...........: _BrowseImageFile
; Description....: Opens a file dialog for the user to select an image. If successful, it copies and converts the image to the
;                  correct format (.bmp) and path for the specified slot, then updates the GUI.
; Parameters.....: $iIndex - The image slot index (0-11) to assign the selected image to.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _BrowseImageFile($iIndex)
	_UpdateStatus("Selecting image file for slot " & ($iIndex + 1) & "...")

	; Define the filter for the file dialog to show common image types.
	Local $sImageFilter = "Image Files (*.bmp;*.jpg;*.jpeg;*.png;*.gif;*.tif;*.tiff)|All Files (*.*)"
	Local $sSelectedFile = FileOpenDialog("Select Image File for Slot " & ($iIndex + 1), @MyDocumentsDir, $sImageFilter, 1 + 2) ; 1=FileMustExist, 2=PathMustExist

	If @error Then
		_LogWrite("INFO: Image file selection cancelled for slot " & ($iIndex + 1))
		_UpdateStatus("Ready")
		Return
	EndIf

	; Validate that the selected file is a valid, processable image.
	If Not _ValidateImageFile($sSelectedFile) Then
		_LogWrite("ERROR: Invalid or corrupted image file selected: " & $sSelectedFile)
		MsgBox(16, "Error", "The selected file is not a valid or supported image!")
		_UpdateStatus("Ready")
		Return
	EndIf

	Local $sTargetPath = $g_asImagePaths[$iIndex]
	Local $bSuccess = False

	; Use GDI+ to load the image and save it as a BMP. This ensures compatibility with the ImageSearchEx DLL.
	Local $hImage = _GDIPlus_ImageLoadFromFile($sSelectedFile)
	If $hImage Then
		If _GDIPlus_ImageSaveToFile($hImage, $sTargetPath) Then
			$bSuccess = True
			_LogWrite("INFO: Image converted and saved as BMP: " & $sTargetPath)
		Else
			_LogWrite("ERROR: Failed to save converted image as BMP. Error: " & @error)
		EndIf
		_GDIPlus_ImageDispose($hImage) ; Clean up GDI+ resources.
	Else
		_LogWrite("ERROR: Failed to load image file with GDI+: " & $sSelectedFile)
	EndIf

	If $bSuccess Then
		_UpdateSingleImagePreview($iIndex)
		_RefreshImageTooltips()
		GUICtrlSetState($g_aidChkSearch[$iIndex], $GUI_CHECKED) ; Auto-check the box for the new image.
		_LogWrite("SUCCESS: Image file loaded for slot " & ($iIndex + 1))
	Else
		MsgBox(16, "Error", "Failed to process the selected image file!")
	EndIf

	_UpdateStatus("Ready")
EndFunc   ;==>_BrowseImageFile

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateSearchModeControls
; Description....: Enables or disables relevant GUI controls based on whether "Search on Screen" or "Search in Image" is selected.
;                  This prevents users from selecting incompatible options.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateSearchModeControls()
	Local $bIsScreenSearch = __IsChecked($g_idRadSearchOnScreen)
	Local $iEnableState = ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE)

	; These controls are only applicable when searching on the screen.
	GUICtrlSetState($g_idChkWait, $iEnableState)
	GUICtrlSetState($g_idInputWaitTime, $iEnableState)
	GUICtrlSetState($g_idChkUseArea, $iEnableState)
	GUICtrlSetState($g_idInputLeft, $iEnableState)
	GUICtrlSetState($g_idInputTop, $iEnableState)
	GUICtrlSetState($g_idInputRight, $iEnableState)
	GUICtrlSetState($g_idInputBottom, $iEnableState)
	GUICtrlSetState($g_idBtnSelectArea, $iEnableState)
	GUICtrlSetState($g_idChkMoveMouse, $iEnableState)
	GUICtrlSetState($g_idRadNoClick, $iEnableState)
	GUICtrlSetState($g_idRadSingleClick, $iEnableState)
	GUICtrlSetState($g_idRadDoubleClick, $iEnableState)
EndFunc   ;==>_UpdateSearchModeControls

; #FUNCTION# ====================================================================================================================
; Name...........: _BrowseSourceImage
; Description....: Opens a file dialog to allow the user to select the source image for an image-in-image search.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _BrowseSourceImage()
	Local $sFile = FileOpenDialog("Select Source Image", @ScriptDir, "Image Files (*.bmp;*.jpg;*.jpeg;*.png;*.gif;*.tif;*.tiff)|All Files (*.*)", 1)
	If @error Then
		_LogWrite("INFO: Source image selection cancelled.")
		Return
	EndIf
	GUICtrlSetData($g_idInputSourceImage, $sFile)
	_LogWrite("INFO: Source image selected: " & $sFile)
EndFunc   ;==>_BrowseSourceImage

; #FUNCTION# ====================================================================================================================
; Name...........: _HandleImageCreation
; Description....: Event handler for all "Create" button clicks. It identifies which button was pressed and calls the screen capture function.
; Parameters.....: $nMsg - The control ID of the pressed Create button.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _HandleImageCreation($nMsg)
	For $i = 0 To $MAX_IMAGES - 1
		If $nMsg = $g_aidBtnCreate[$i] Then
			_CreateImageFile($i)
			Return ; Exit the loop once handled.
		EndIf
	Next
EndFunc   ;==>_HandleImageCreation

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateImageFile
; Description....: Manages the process of capturing a screen region. It calls the capture function and updates the GUI based on the result.
; Parameters.....: $iIndex - The index of the image slot (0-11) to create the image for.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateImageFile($iIndex)
	_UpdateStatus("Preparing to create image " & $iIndex + 1 & "...")
	Local $sFilePath = $g_asImagePaths[$iIndex]
	Local $sTitle = "Create/Update Image " & $iIndex + 1

	Local $iResult = _CaptureRegion_free($sTitle, $sFilePath)

	Switch $iResult
		Case 0 ; Success
			_LogWrite("SUCCESS: Image saved to: " & $sFilePath)
			_UpdateSingleImagePreview($iIndex)
			_RefreshImageTooltips()
			GUICtrlSetState($g_aidChkSearch[$iIndex], $GUI_CHECKED) ; Auto-check the box for the new image.
		Case -1 ; Error
			_LogWrite("ERROR: Failed to capture screen region.")
		Case -2 ; Cancelled
			_LogWrite("CANCELLED: User cancelled image creation for " & $sFilePath)
	EndSwitch

	_UpdateStatus("Ready")
EndFunc   ;==>_CreateImageFile

; #FUNCTION# ====================================================================================================================
; Name...........: _SelectAreaOnScreen
; Description....: Manages the process of selecting a screen area for a restricted search and updates the GUI input fields with the coordinates.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _SelectAreaOnScreen()
	_UpdateStatus("Preparing to select search area...")
	Local $aCoords = _CaptureRegion_free("Select a search area and release the mouse", "")

	If Not IsArray($aCoords) Then
		_LogWrite("INFO: Area selection cancelled.")
	Else
		GUICtrlSetData($g_idInputLeft, $aCoords[0])
		GUICtrlSetData($g_idInputTop, $aCoords[1])
		GUICtrlSetData($g_idInputRight, $aCoords[2])
		GUICtrlSetData($g_idInputBottom, $aCoords[3])
		GUICtrlSetState($g_idChkUseArea, $GUI_CHECKED) ; Automatically check the "Use Custom Area" box.
		_LogWrite("INFO: Search area updated to L:" & $aCoords[0] & " T:" & $aCoords[1] & " R:" & $aCoords[2] & " B:" & $aCoords[3])
	EndIf

	_UpdateStatus("Ready")
EndFunc   ;==>_SelectAreaOnScreen

#EndRegion ; === END EVENT HANDLERS & GUI LOGIC ===


; #REGION# === CORE SEARCH LOGIC ===

; #FUNCTION# ====================================================================================================================
; Name...........: _StartSearch
; Description....: The main function triggered by the "Start Search" button. It gathers all settings from the GUI, validates them,
;                  and then calls the appropriate search function based on the selected mode.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _StartSearch()
	GUICtrlSetData($g_hLog, "") ; Clear the log for the new search.
	_UpdateStatus("Starting search...")

	; --- Read and Validate GUI inputs ---
	Local $bIsScreenSearch = __IsChecked($g_idRadSearchOnScreen)
	Local $sSourceImage = GUICtrlRead($g_idInputSourceImage)
	Local $iDelay = Number(GUICtrlRead($g_idInputDelay))
	Local $bMoveMouse = __IsChecked($g_idChkMoveMouse)
	Local $iClickType = 0 ; 0 = None, 1 = Single, 2 = Double
	If __IsChecked($g_idRadSingleClick) Then $iClickType = 1
	If __IsChecked($g_idRadDoubleClick) Then $iClickType = 2
	Local $bWaitSearch = __IsChecked($g_idChkWait)
	Local $iWaitTime = Number(GUICtrlRead($g_idInputWaitTime))
	Local $bMultiSearch = __IsChecked($g_idChkMultiSearch)
	Local $iFindAll = (__IsChecked($g_idChkFindAll) ? 1 : 0) ; Convert checkbox state to 1 or 0
	Local $iTolerance = Number(GUICtrlRead($g_idInputTolerance))
	Local $iDebugMode = (__IsChecked($g_idChkEnableDebug) ? 1 : 0)

	; --- Validate source image for image-in-image search ---
	If Not $bIsScreenSearch Then
		If Not FileExists($sSourceImage) Then
			_LogWrite("ERROR: Source image file not found: " & $sSourceImage)
			_UpdateStatus("Error: Source image not found. Ready.")
			Return
		EndIf
		; Mouse actions and waiting are not applicable for image-in-image searches.
		$bMoveMouse = False
		$iClickType = 0
		$bWaitSearch = False
	EndIf

	; --- Determine Search Area ---
	Local $iLeft, $iTop, $iRight, $iBottom
	If $bIsScreenSearch And __IsChecked($g_idChkUseArea) Then
		$iLeft = GUICtrlRead($g_idInputLeft)
		$iTop = GUICtrlRead($g_idInputTop)
		$iRight = GUICtrlRead($g_idInputRight)
		$iBottom = GUICtrlRead($g_idInputBottom)
	Else
		; Default to the entire screen if no custom area is specified.
		$iLeft = 0
		$iTop = 0
		$iRight = @DesktopWidth
		$iBottom = @DesktopHeight
	EndIf

	; --- Get a list of all checked and valid image files to search for ---
	Local $aSearchList[1] = [0] ; Initialize an array to hold the paths. Index 0 stores the count.
	For $i = 0 To $MAX_IMAGES - 1
		If __IsChecked($g_aidChkSearch[$i]) Then
			If Not FileExists($g_asImagePaths[$i]) Then
				_LogWrite("WARN: Image " & $i + 1 & " (" & $g_asImagePaths[$i] & ") not found. Unchecking and skipping.")
				GUICtrlSetState($g_aidChkSearch[$i], $GUI_UNCHECKED)
				_UpdateSingleImagePreview($i) ; Update preview to show it's missing.
				ContinueLoop
			EndIf
			_ArrayAdd($aSearchList, $g_asImagePaths[$i])
		EndIf
	Next
	$aSearchList[0] = UBound($aSearchList) - 1 ; Update the count.


	If $aSearchList[0] = 0 Then
		_LogWrite("ERROR: No valid images selected for search.")
		_UpdateStatus("Error: No valid images selected. Ready.")
		Return
	EndIf

	_LogWrite("====================================")
	_LogWrite("Starting search for " & $aSearchList[0] & " image(s)...")

	; --- Call the appropriate search function based on the mode ---
	If $bIsScreenSearch Then
		If $bMultiSearch Then
			_SearchMultipleImages($aSearchList, $bWaitSearch, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebugMode, $iFindAll, $bMoveMouse, $iClickType, $iDelay)
		Else
			_SearchSingleImages($aSearchList, $bWaitSearch, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebugMode, $iFindAll, $bMoveMouse, $iClickType, $iDelay)
		EndIf
	Else
		_SearchInImage($aSearchList, $sSourceImage, $iTolerance, $iDebugMode, $iFindAll, $iDelay)
	EndIf

	_LogWrite("====================================" & @CRLF)
	_UpdateStatus("Search complete. Ready.")
EndFunc   ;==>_StartSearch

; #FUNCTION# ====================================================================================================================
; Name...........: _SearchMultipleImages
; Description....: Performs a search for all selected images at once (multi-search) on the screen.
; Parameters.....: $aImageList - Array of image paths to search for.
;                  ... All other parameters are search and action settings from the GUI.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _SearchMultipleImages($aImageList, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll, $bMove, $iClickType, $iDelay)
	_UpdateStatus("Mode: Multi Search (All at once)...")
	_LogWrite("Mode: Multi Search (All at once)")
	_LogWrite("Find All Occurrences: " & ($iFindAll = 1 ? "Enabled" : "Disabled") & @CRLF)

	; Combine all image paths into a single pipe-delimited string for the UDF.
	Local $sImageListStr = _ArrayToString($aImageList, "|", 1)

	Local $aResult = __ExecuteSearch($sImageListStr, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll)

	If $iDebug = 1 Then _LogWrite("DLL Return: " & $g_sLastDllReturn)

	If IsArray($aResult) And $aResult[0][0] > 0 Then
		_ProcessMultiResults($aResult, $bMove, $iClickType, $iDelay)
	Else
		_LogSearchError(IsArray($aResult) ? $aResult[0][0] : 0)
	EndIf
EndFunc   ;==>_SearchMultipleImages

; #FUNCTION# ====================================================================================================================
; Name...........: _SearchSingleImages
; Description....: Performs a search for each selected image individually, one by one, on the screen.
; Parameters.....: $aImageList - Array of image paths to search for.
;                  ... All other parameters are search and action settings from the GUI.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _SearchSingleImages($aImageList, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll, $bMove, $iClickType, $iDelay)
	_LogWrite("Mode: Single Search (One by one)")
	_LogWrite("Find All Occurrences: " & ($iFindAll = 1 ? "Enabled" : "Disabled") & @CRLF)

	Local $iTotalFound = 0

	For $i = 1 To $aImageList[0]
		Local $sCurrentImage = $aImageList[$i]
		Local $sImageName = StringRegExpReplace($sCurrentImage, ".+\\(.+)", "$1")
		_UpdateStatus("Searching for: " & $sImageName & "...")
		_LogWrite(" -> Searching for: " & $sImageName)

		Local $aResult = __ExecuteSearch($sCurrentImage, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll)

		If $iDebug = 1 Then _LogWrite("DLL Return: " & $g_sLastDllReturn)

		If IsArray($aResult) And $aResult[0][0] > 0 Then
			$iTotalFound += $aResult[0][0]
			_ProcessMultiResults($aResult, $bMove, $iClickType, $iDelay)
		Else
			_LogSearchError(IsArray($aResult) ? $aResult[0][0] : 0)
		EndIf
	Next

	_LogWrite("Single search finished. Total matches found: " & $iTotalFound)
EndFunc   ;==>_SearchSingleImages

; #FUNCTION# ====================================================================================================================
; Name...........: _SearchInImage
; Description....: Performs a search for selected target images within a larger source image file.
; Parameters.....: $aImageList   - Array of target image paths.
;                  $sSourceImage - Path to the source image to search within.
;                  ... All other parameters are search settings from the GUI.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _SearchInImage($aImageList, $sSourceImage, $iTolerance, $iDebug, $iFindAll, $iDelay)
	_UpdateStatus("Mode: Image-in-Image Search...")
	_LogWrite("Mode: Image-in-Image Search")
	_LogWrite("Source Image: " & $sSourceImage)
	_LogWrite("Find All Occurrences: " & ($iFindAll = 1 ? "Enabled" : "Disabled") & @CRLF)

	Local $iTotalFound = 0

	If __IsChecked($g_idChkMultiSearch) Then
		; Perform a multi-image search within the source image.
		Local $sImageListStr = _ArrayToString($aImageList, "|", 1)
		_UpdateStatus("Searching for multiple images in: " & StringRegExpReplace($sSourceImage, ".*\\", "") & "...")
		_LogWrite(" -> Searching for multiple images at once.")
		Local $aResult = __ExecuteImageInImageSearchEx($sSourceImage, $sImageListStr, $iTolerance, $iDebug, $iFindAll)

		If $iDebug = 1 Then _LogWrite("DLL Return: " & $g_sLastDllReturn)

		If IsArray($aResult) And $aResult[0][0] > 0 Then
			$iTotalFound += $aResult[0][0]
			_ProcessImageInImageResults($aResult, $iDelay)
		Else
			_LogSearchError(IsArray($aResult) ? $aResult[0][0] : 0)
		EndIf
	Else
		; Perform a single search for each image, one by one.
		For $i = 1 To $aImageList[0]
			Local $sCurrentImage = $aImageList[$i]
			Local $sImageName = StringRegExpReplace($sCurrentImage, ".+\\(.+)", "$1")
			_UpdateStatus("Searching for: " & $sImageName & " in source image...")
			_LogWrite(" -> Searching for: " & $sImageName)
			Local $aResult = __ExecuteImageInImageSearchEx($sSourceImage, $sCurrentImage, $iTolerance, $iDebug, $iFindAll)

			If $iDebug = 1 Then _LogWrite("DLL Return: " & $g_sLastDllReturn)

			If IsArray($aResult) And $aResult[0][0] > 0 Then
				$iTotalFound += $aResult[0][0]
				_ProcessImageInImageResults($aResult, $iDelay)
			Else
				_LogSearchError(IsArray($aResult) ? $aResult[0][0] : 0)
			EndIf
		Next
	EndIf

	_LogWrite("Image-in-image search finished. Total matches found: " & $iTotalFound)
EndFunc   ;==>_SearchInImage

; #FUNCTION# ====================================================================================================================
; Name...........: __ExecuteSearch
; Description....: A centralized wrapper function to call the appropriate screen search UDF. This version is corrected
;                  to properly use the area coordinates gathered from the GUI, making the "Search Area" feature functional.
; Parameters.....: All parameters required by the _ImageSearchEx_Area UDF.
; Return values..: The 2D array result from the UDF, or an error code.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func __ExecuteSearch($sImagePath, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll)
	Local $iMaxResults = ($iFindAll = 1 ? 99 : 1)
	If $bWait Then
		; Since the simple _ImageSearchEx_Wait UDF doesn't support area parameters, we implement a custom wait loop
		; here using the more advanced _ImageSearchEx_Area function. This makes the "Wait" and "Search Area" features
		; work together correctly as intended by the GUI design.
		Local $aResult
		Local $hTimer = TimerInit()
		While TimerDiff($hTimer) < $iWaitTime
			Sleep(100) ; Brief pause between search attempts to reduce CPU usage.
			$aResult = _ImageSearchEx_Area($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, -1, $iMaxResults, 1, $iDebug, 1.0, 1.0, 0.1, $iFindAll)
			If IsArray($aResult) And $aResult[0][0] > 0 Then Return $aResult ; Image found, return result immediately.
		WEnd
		Return __ImgSearchEx_Make2DResultArray(0) ; Return an empty array if the timeout is reached.
	Else
		; For a non-waiting search, directly call _ImageSearchEx_Area with all parameters.
		Return _ImageSearchEx_Area($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, -1, $iMaxResults, 1, $iDebug, 1.0, 1.0, 0.1, $iFindAll)
	EndIf
EndFunc   ;==>__ExecuteSearch

; #FUNCTION# ====================================================================================================================
; Name...........: __ExecuteImageInImageSearchEx
; Description....: A wrapper function to call the _ImageInImageSearchEx_Advanced UDF to ensure all parameters are handled correctly.
; Parameters.....: All parameters required by the _ImageInImageSearchEx_Advanced UDF.
; Return values..: The 2D array result from the UDF, or an error code.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func __ExecuteImageInImageSearchEx($sSourceImagePath, $sTargetImagePath, $iTolerance, $iDebug, $iFindAll)
	Local $iMaxResults = ($iFindAll = 1 ? 99 : 1)
	; Using the _Advanced version to correctly pass the debug parameter from the GUI.
	Return _ImageInImageSearchEx_Advanced($sSourceImagePath, $sTargetImagePath, $iTolerance, -1, $iMaxResults, 1, $iDebug, 1.0, 1.0, 0.1, $iFindAll)
EndFunc   ;==>__ExecuteImageInImageSearchEx

#EndRegion ; === END CORE SEARCH LOGIC ===


; #REGION# === RESULT PROCESSING & ACTIONS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _ProcessMultiResults
; Description....: Processes the 2D array result from a successful screen search. It iterates through each found match and
;                  performs the user-defined actions (highlight, move, click).
; Parameters.....: $aResult    - The 2D result array from the UDF.
;                  $bMove      - Boolean, whether to move the mouse.
;                  $iClickType - 0 for none, 1 for single, 2 for double click.
;                  $iDelay     - Delay in ms after actions.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _ProcessMultiResults($aResult, $bMove, $iClickType, $iDelay)
	Local $iFoundCount = $aResult[0][0]
	_LogWrite("Success: Found " & $iFoundCount & " match(es). Performing actions...")
	For $i = 1 To $iFoundCount
		Local $iX = $aResult[$i][1], $iY = $aResult[$i][2], $iW = $aResult[$i][3], $iH = $aResult[$i][4]
		_UpdateStatus("Performing action on match #" & $i & " at " & $iX & "," & $iY & "...")
		_LogWrite("  -> Found match #" & $i & " at X=" & $iX & ", Y=" & $iY)
		_HighlightFoundArea($iX, $iY, $iW, $iH, 0xFF00FF00) ; Highlight in green
		_PerformActions($iX, $iY, $bMove, $iClickType, $iDelay)
	Next
	_LogWrite("All actions complete for this search cycle.")
EndFunc   ;==>_ProcessMultiResults

; #FUNCTION# ====================================================================================================================
; Name...........: _ProcessImageInImageResults
; Description....: Processes the 2D array result from a successful image-in-image search. It simply logs the coordinates of each match.
; Parameters.....: $aResult    - The 2D result array from the UDF.
;                  $iDelay     - Delay in ms after logging each result (for readability).
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _ProcessImageInImageResults($aResult, $iDelay)
	Local $iFoundCount = $aResult[0][0]
	_LogWrite("Success: Found " & $iFoundCount & " match(es) in source image.")
	For $i = 1 To $iFoundCount
		Local $iX = $aResult[$i][1], $iY = $aResult[$i][2], $iW = $aResult[$i][3], $iH = $aResult[$i][4]
		_UpdateStatus("Found match #" & $i & " at " & $iX & "," & $iY & " in source image...")
		_LogWrite("  -> Found match #" & $i & " at X=" & $iX & ", Y=" & $iY & ", Width=" & $iW & ", Height=" & $iH)
		Sleep($iDelay)
	Next
	_LogWrite("All results logged for this search cycle." & @CRLF)
EndFunc   ;==>_ProcessImageInImageResults

; #FUNCTION# ====================================================================================================================
; Name...........: _PerformActions
; Description....: Executes the user-defined actions (move mouse, click, delay) at a given coordinate.
; Parameters.....: $iX, $iY    - The coordinates to perform actions at.
;                  $bMove      - Boolean, whether to move the mouse.
;                  $iClickType - 0 for none, 1 for single, 2 for double click.
;                  $iDelay     - Delay in ms after actions.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _PerformActions($iX, $iY, $bMove, $iClickType, $iDelay)
	If $bMove Then
		_LogWrite("     - Moving mouse to (" & $iX & ", " & $iY & ")")
		MouseMove($iX, $iY, 10) ; Speed 10 for a smooth move
	EndIf

	If $iClickType > 0 Then
		_LogWrite("     - Performing " & ($iClickType = 1 ? "single" : "double") & " click...")
		MouseClick("left", $iX, $iY, $iClickType, 0) ; Click at the location.
	EndIf

	If $iDelay > 0 Then
		_LogWrite("     - Delaying for " & $iDelay & "ms...")
		Sleep($iDelay)
	EndIf
EndFunc   ;==>_PerformActions

#EndRegion ; === END RESULT PROCESSING & ACTIONS ===


; #REGION# === SCREEN CAPTURE & AREA SELECTION ===

; #FUNCTION# ====================================================================================================================
; Name...........: _CaptureRegion_free
; Description....: Creates a transparent GUI to allow the user to select a screen region by dragging the mouse. Can either
;                  save the captured area to a file or return its coordinates.
; Parameters.....: $sTitle    - The title for the capture instruction window.
;                  $sFilePath - If a path is provided, captures and saves an image. If empty, returns coordinates.
; Return values..: If $sFilePath is provided: 0 on success, -1 on capture error, -2 on user cancel.
;                  If $sFilePath is empty: A 4-element array [Left, Top, Right, Bottom] on success, or -2 on user cancel.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CaptureRegion_free($sTitle, $sFilePath)
	GUISetState(@SW_HIDE, $g_hMainGUI)
	Sleep(250) ; Allow time for the GUI to hide

	Local $hUserDLL = DllOpen("user32.dll")
	If $hUserDLL = -1 Then Return -1

	; Create a fullscreen, transparent window to capture mouse events.
	Local $hCrossGUI = GUICreate($sTitle, @DesktopWidth, @DesktopHeight, 0, 0, $WS_POPUP, $WS_EX_TOPMOST)
	GUISetBkColor(0x000001) ; A color that is unlikely to be on screen.
	WinSetTrans($hCrossGUI, "", 1) ; Make it almost fully transparent.
	GUISetState(@SW_SHOW, $hCrossGUI)
	GUISetCursor(3, 1, $hCrossGUI) ; Set crosshair cursor.

	_UpdateStatus("Drag the mouse to select an area. Press ESC to cancel.")
	ToolTip("Drag the mouse to select an area. Press ESC to cancel.", 0, 0)

	; Wait for the user to press the left mouse button.
	While Not _IsPressed("01", $hUserDLL)
		If _IsPressed("1B", $hUserDLL) Then ; Check for ESC key press to cancel.
			ToolTip("")
			GUIDelete($hCrossGUI)
			DllClose($hUserDLL)
			GUISetState(@SW_SHOW, $g_hMainGUI)
			Return -2
		EndIf
		Sleep(20)
	WEnd
	ToolTip("")

	Local $aStartPos = MouseGetPos()
	Local $iX1 = $aStartPos[0], $iY1 = $aStartPos[1]
	Local $hRectGUI

	; While the mouse button is held down, draw a feedback rectangle.
	While _IsPressed("01", $hUserDLL)
		Local $aCurrentPos = MouseGetPos()
		Local $iX2 = $aCurrentPos[0], $iY2 = $aCurrentPos[1]
		If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)

		Local $iLeft = ($iX1 < $iX2 ? $iX1 : $iX2)
		Local $iTop = ($iY1 < $iY2 ? $iY1 : $iY2)
		Local $iWidth = Abs($iX1 - $iX2)
		Local $iHeight = Abs($iY1 - $iY2)

		$hRectGUI = GUICreate("", $iWidth, $iHeight, $iLeft, $iTop, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST))
		GUISetBkColor(0xFF0000) ; Red feedback rectangle.
		_WinAPI_SetLayeredWindowAttributes($hRectGUI, 0, 100) ; Set transparency.
		GUISetState(@SW_SHOWNOACTIVATE, $hRectGUI)
		Sleep(10)
	WEnd

	Local $aEndPos = MouseGetPos()
	Local $iX2 = $aEndPos[0], $iY2 = $aEndPos[1]

	; Clean up the temporary GUIs.
	GUIDelete($hCrossGUI)
	If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)
	DllClose($hUserDLL)

	; Final coordinate calculation.
	Local $iLeft = ($iX1 < $iX2 ? $iX1 : $iX2)
	Local $iTop = ($iY1 < $iY2 ? $iY1 : $iY2)
	Local $iRight = ($iX1 > $iX2 ? $iX1 : $iX2)
	Local $iBottom = ($iY1 > $iY2 ? $iY1 : $iY2)

	GUISetState(@SW_SHOW, $g_hMainGUI)

	; If no area was selected (no drag), treat as a cancel.
	If $iLeft = $iRight Or $iTop = $iBottom Then Return -2

	; If a file path was provided, capture the screen area to that file.
	If $sFilePath <> "" Then
		Local $aMousePos = MouseGetPos()
		MouseMove(0, 0, 0) ; Move mouse out of the way for a clean capture.
		Sleep(250)
		Local $hBitmap = _ScreenCapture_Capture("", $iLeft, $iTop, $iRight, $iBottom, False)
		If @error Then
			MouseMove($aMousePos[0], $aMousePos[1], 0)
			Return -1 ; Return error if capture failed.
		EndIf
		Local $hImage = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)
		_GDIPlus_ImageSaveToFile($hImage, $sFilePath)
		_GDIPlus_BitmapDispose($hImage)
		_WinAPI_DeleteObject($hBitmap)
		MouseMove($aMousePos[0], $aMousePos[1], 0) ; Restore mouse position.
		Return 0 ; Success.
	Else
		; If no file path, return the coordinates array.
		Local $aReturn[4] = [$iLeft, $iTop, $iRight, $iBottom]
		Return $aReturn
	EndIf
EndFunc   ;==>_CaptureRegion_free

#EndRegion ; === END SCREEN CAPTURE & AREA SELECTION ===


; #REGION# === UTILITY & HELPER FUNCTIONS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _HighlightFoundArea
; Description....: Creates a temporary, semi-transparent GUI to visually highlight a found image location on the screen.
; Parameters.....: $iX, $iY    - The center coordinates of the area to highlight.
;                  $iWidth     - The width of the highlight rectangle.
;                  $iHeight    - The height of the highlight rectangle.
;                  $iColor     - [optional] The color of the highlight rectangle in 0xRRGGBB format. Default is green.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _HighlightFoundArea($iX, $iY, $iWidth, $iHeight, $iColor = 0xFF00FF00)
	Local $hGUI = GUICreate("", $iWidth, $iHeight, $iX - $iWidth / 2, $iY - $iHeight / 2, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
	GUISetBkColor($iColor)
	_WinAPI_SetLayeredWindowAttributes($hGUI, 0, 128) ; 50% transparency.
	GUISetState(@SW_SHOWNOACTIVATE)
	Sleep(500) ; Display the highlight for half a second.
	GUIDelete($hGUI)
EndFunc   ;==>_HighlightFoundArea

; #FUNCTION# ====================================================================================================================
; Name...........: _LogWrite
; Description....: Writes a timestamped message to the activity log Edit control and ensures it scrolls to the latest entry.
; Parameters.....: $sMessage - The string message to log.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _LogWrite($sMessage)
	GUICtrlSetData($g_hLog, "[" & _NowTime(5) & "] " & $sMessage & @CRLF, 1) ; The '1' appends the text.
	_GUICtrlEdit_SetSel(GUICtrlGetHandle($g_hLog), 0x7FFFFFFF, 0x7FFFFFFF) ; Scroll to the end.
EndFunc   ;==>_LogWrite

; #FUNCTION# ====================================================================================================================
; Name...........: _LogSearchError
; Description....: Translates a numerical error code from the ImageSearchEx UDF into a human-readable message and logs it.
; Parameters.....: $iErrorCode - The status code returned by an _ImageSearchEx* function.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _LogSearchError($iErrorCode)
	Switch $iErrorCode
		Case 0
			_LogWrite("    - Result: Not found." & @CRLF)
		Case -1
			_LogWrite("ERROR: DllCall failed. The ImageSearchEx DLL might be missing, corrupted, or blocked by antivirus.")
		Case -2
			_LogWrite("ERROR: Invalid format returned from DLL. The UDF could not parse the result.")
		Case -3
			_LogWrite("ERROR: Invalid content returned from DLL. The result string was malformed.")
		Case -11
			_LogWrite("ERROR: The source or target image file was not found on disk (as checked by the UDF).")
		Case -12
			_LogWrite("ERROR: Failed to deploy or load the ImageSearchEx DLL. Ensure _ImageSearchEx_Startup() was called successfully.")
		Case Else
			_LogWrite("ERROR: An unknown internal DLL error occurred. Code: " & $iErrorCode)
	EndSwitch
EndFunc   ;==>_LogSearchError

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateAllImagePreviews
; Description....: Iterates through all image slots and calls the function to update their preview images.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateAllImagePreviews()
	For $i = 0 To $MAX_IMAGES - 1
		_UpdateSingleImagePreview($i)
	Next
EndFunc   ;==>_UpdateAllImagePreviews

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateSingleImagePreview
; Description....: Updates a single image preview slot. If the target image file exists, it's displayed. Otherwise, a placeholder is shown.
; Parameters.....: $iIndex - The index (0-11) of the image slot to update.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateSingleImagePreview($iIndex)
	If FileExists($g_asImagePaths[$iIndex]) Then
		GUICtrlSetImage($g_aidPic[$iIndex], $g_asImagePaths[$iIndex])
	Else
		; Use a default Windows wallpaper as a placeholder if available.
		If FileExists($g_sPlaceholderPath) Then
			GUICtrlSetImage($g_aidPic[$iIndex], $g_sPlaceholderPath)
		Else
			; Fallback to a generic icon from shell32.dll if the wallpaper is also missing.
			GUICtrlSetImage($g_aidPic[$iIndex], "shell32.dll", 22)
		EndIf
	EndIf
EndFunc   ;==>_UpdateSingleImagePreview

; #FUNCTION# ====================================================================================================================
; Name...........: _SelectAll
; Description....: Checks or unchecks all image target checkboxes simultaneously.
; Parameters.....: $bState - True to check all, False to uncheck all.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _SelectAll($bState)
	Local $iCheckState = ($bState ? $GUI_CHECKED : $GUI_UNCHECKED)

	For $i = 0 To $MAX_IMAGES - 1
		GUICtrlSetState($g_aidChkSearch[$i], $iCheckState)
	Next
EndFunc   ;==>_SelectAll

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateStatus
; Description....: Sets the text of the status bar at the bottom of the GUI.
; Parameters.....: $sMessage - The message to display.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateStatus($sMessage)
	_GUICtrlStatusBar_SetText($g_hStatusBar, $sMessage)
EndFunc   ;==>_UpdateStatus

; #FUNCTION# ====================================================================================================================
; Name...........: __IsChecked
; Description....: A helper function to check the state of a checkbox or radio button in a more readable way.
; Parameters.....: $iControlID - The control ID of the checkbox or radio button.
; Return values..: True if the control is checked, False otherwise.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func __IsChecked($iControlID)
	Return BitAND(GUICtrlRead($iControlID), $GUI_CHECKED) = $GUI_CHECKED
EndFunc   ;==>__IsChecked

; #FUNCTION# ====================================================================================================================
; Name...........: _GetImageDimensions
; Description....: Gets the width and height of an image file using GDI+.
; Parameters.....: $sImagePath - Path to the image file.
; Return values..: On success, a 2-element array [Width, Height]. On failure, returns False.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _GetImageDimensions($sImagePath)
	If Not FileExists($sImagePath) Then Return False

	Local $hImage = _GDIPlus_ImageLoadFromFile($sImagePath)
	If Not $hImage Then Return False

	Local $iWidth = _GDIPlus_ImageGetWidth($hImage)
	Local $iHeight = _GDIPlus_ImageGetHeight($hImage)
	_GDIPlus_ImageDispose($hImage)

	Local $aDimensions[2] = [$iWidth, $iHeight]
	Return $aDimensions
EndFunc   ;==>_GetImageDimensions

; #FUNCTION# ====================================================================================================================
; Name...........: _ValidateImageFile
; Description....: Validates if a file is a valid image that can be processed by GDI+. Checks for existence, size, and basic integrity.
; Parameters.....: $sImagePath - Path to the image file.
; Return values..: True if the image is valid, False otherwise.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _ValidateImageFile($sImagePath)
	If Not FileExists($sImagePath) Then Return False

	; Check file size (must be > 0 and < 50MB for reasonable processing)
	Local $iFileSize = FileGetSize($sImagePath)
	If $iFileSize <= 0 Or $iFileSize > 50 * 1024 * 1024 Then Return False

	; Try to load with GDI+ to validate it's a real, uncorrupted image.
	Local $hImage = _GDIPlus_ImageLoadFromFile($sImagePath)
	If Not $hImage Then Return False

	; Check minimum dimensions (at least 1x1 pixel).
	Local $iWidth = _GDIPlus_ImageGetWidth($hImage)
	Local $iHeight = _GDIPlus_ImageGetHeight($hImage)
	_GDIPlus_ImageDispose($hImage)

	Return ($iWidth > 0 And $iHeight > 0)
EndFunc   ;==>_ValidateImageFile

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateImageInfoTooltip
; Description....: Creates a detailed tooltip string for an image slot, showing file name, dimensions, file size, and full path.
; Parameters.....: $iIndex - The index (0-11) of the image slot.
; Return values..: A formatted string containing the image's information for use in a tooltip.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateImageInfoTooltip($iIndex)
	Local $sImagePath = $g_asImagePaths[$iIndex]
	Local $sTooltip = "Slot " & ($iIndex + 1) & ":" & @CRLF

	If FileExists($sImagePath) Then
		Local $aDims = _GetImageDimensions($sImagePath)
		Local $iFileSize = FileGetSize($sImagePath)
		Local $sFileSize = ""

		If $iFileSize < 1024 Then
			$sFileSize = $iFileSize & " B"
		ElseIf $iFileSize < 1024 * 1024 Then
			$sFileSize = Round($iFileSize / 1024, 1) & " KB"
		Else
			$sFileSize = Round($iFileSize / (1024 * 1024), 2) & " MB"
		EndIf

		$sTooltip &= "File: " & StringRegExpReplace($sImagePath, ".*\\", "") & @CRLF
		If IsArray($aDims) Then
			$sTooltip &= "Size: " & $aDims[0] & " x " & $aDims[1] & " px" & @CRLF
		EndIf
		$sTooltip &= "File Size: " & $sFileSize & @CRLF
		$sTooltip &= "Path: " & $sImagePath
	Else
		$sTooltip &= "No image file." & @CRLF
		$sTooltip &= "Click 'Create' or 'Browse'."
	EndIf

	Return $sTooltip
EndFunc   ;==>_CreateImageInfoTooltip

; #FUNCTION# ====================================================================================================================
; Name...........: _RefreshImageTooltips
; Description....: Updates the tooltips for all image preview controls with the latest file information.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _RefreshImageTooltips()
	For $i = 0 To $MAX_IMAGES - 1
		GUICtrlSetTip($g_aidPic[$i], _CreateImageInfoTooltip($i))
	Next
EndFunc   ;==>_RefreshImageTooltips

; #FUNCTION# ====================================================================================================================
; Name...........: _Exit
; Description....: Performs cleanup operations (like shutting down GDI+) and exits the script cleanly.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _Exit()
	_GDIPlus_Shutdown()
	Exit
EndFunc   ;==>_Exit

#EndRegion ; === END UTILITY & HELPER FUNCTIONS ===

