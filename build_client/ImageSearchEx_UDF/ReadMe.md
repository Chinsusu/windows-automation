# **ImageSearchDLL & UDF - The Complete Guide**

**Author:** Dao Van Trong - TRONG.PRO

**Last Updated:** 2025-09-15

## **1. Introduction**

**ImageSearchDLL** is a high-performance image recognition solution for Windows, designed to be both powerful for modern systems and compatible with legacy environments. The project consists of three distinct C++ DLL versions and a smart AutoIt User-Defined Function (UDF) that automatically selects the best DLL for the job.

This architecture ensures that your scripts get the best possible performance on modern systems (like Windows 10/11) while maintaining full functionality on older systems like Windows 7 and even Windows XP.

## **2. How it Works: The Smart UDF Loader**

The core of this project is the AutoIt UDF (ImageSearchEx_UDF.au3). You don't need to worry about which DLL to use; the _ImageSearchEx_Startup() function handles it all automatically.

Here is the loading logic:

1. **On Modern OS (Windows 8, 10, 11+):**  
   * It first looks for the **Modern DLL** (ImageSearchEx_x64.dll or ImageSearchEx_x86.dll).  
   * If not found, it falls back to the **Windows 7 DLL**.  
   * If neither is found, it deploys the **Embedded XP DLL**.  
2. **On Windows 7:**  
   * It prioritizes the **Windows 7 DLL** (ImageSearchEx_Win7_x64.dll or ImageSearchEx_Win7_x86.dll).  
   * If not found, it deploys the **Embedded XP DLL**.  
3. **On Windows XP:**  
   * It exclusively uses the **Embedded XP DLL**, which is extracted from a HEX string inside the UDF.

This ensures maximum performance where possible and maximum compatibility where needed.

## **3. The DLL Versions Explained**

There are three distinct DLLs, each compiled for a specific purpose.

| Feature | Modern (Win10+) | Windows 7 | Legacy (XP) |
| :---- | :---- | :---- | :---- |
| **Target OS** | Windows 8, 10, 11+ | **Windows 7 SP1+** | **Windows XP SP3+** |
| **Filename** | ImageSearchEx_x64.dll<br>ImageSearchEx_x86.dll | ImageSearchEx_Win7_x64.dll<br>ImageSearchEx_Win7_x86.dll | Embedded in UDF |
| **Compiler** | VS 2022 (C++23) | VS 2017+ (C++14) | VS 2010 (C++03) |
| **Performance** | **Excellent** | **Very Good** | **Good** |
| **AVX2 Support** | **Yes** (auto-detected) | **Yes** (auto-detected) | **No** |
| **Thread-Safety** | **Yes** (thread_local) | **Yes** (thread_local) | **No** (static buffer) |
| **Best Use Case** | High-performance automation on modern PCs. | Scripts that need to run reliably on both modern systems and Windows 7 machines. | Maximum compatibility for legacy systems or when no external DLLs are provided. |

## **4. Getting Started (For AutoIt Users)**

Using the library is simple. Just make sure your files are organized correctly.

### **File Structure**

For the best experience, place the DLL files in the same directory as your script and the UDF.

/YourScriptFolder/  
|  
|-- MyScript.au3  
|-- ImageSearchEx_UDF.au3  
|-- ImageSearchEx_x64.dll      (Modern DLL for 64-bit)  
|-- ImageSearchEx_x86.dll      (Modern DLL for 32-bit)  
|-- ImageSearchEx_Win7_x64.dll (Win7 DLL for 64-bit)  
|-- ImageSearchEx_Win7_x86.dll (Win7 DLL for 32-bit)  
|  
/-- images/  
    |-- button.png

### **Quick Start Example**

Here is a basic AutoIt script to get you started.

    #include "ImageSearchEx_UDF.au3"
    
    ; 1. Initialize the library. The UDF will automatically load the best DLL.  
    _ImageSearchEx_Startup()  
    If @error Then  
        MsgBox(16, "Error", "ImageSearch DLL could not be initialized. Exiting.")  
        Exit  
    EndIf
    
    ; You can check which version was loaded  
    ConsoleWrite(">> Loaded DLL Version: " & _ImageSearchEx_GetVersion() & @CRLF)  
    ConsoleWrite(">> System Info: " & _ImageSearchEx_GetSysInfo() & @CRLF)
    
    ; 2. Perform a search for an image on the entire screen.  
    Local $sImagePath = @ScriptDir & "\images\button.png"  
    Local $aResult = _ImageSearch($sImagePath)
    
    ; 3. Process the results. The result is ALWAYS a 2D array.  
    If $aResult[0][0] > 0 Then  
        ConsoleWrite("Found " & $aResult[0][0] & " match(es)!" & @CRLF)  
        ; Loop through each match  
        For $i = 1 To $aResult[0][0]  
            Local $iX = $aResult[$i][1] ; X coordinate  
            Local $iY = $aResult[$i][2] ; Y coordinate  
            ConsoleWrite("Match #" & $i & " found at: " & $iX & ", " & $iY & @CRLF)  
            MouseMove($iX, $iY, 20)  
            Sleep(1000)  
        Next  
    Else  
        ConsoleWrite("Image not found." & @CRLF)  
    EndIf
    
    ; 4. Shutdown is handled automatically when the script exits. No need to call _ImageSearchEx_Shutdown().

## **5. Full API Reference**

### **Main Functions**

* _ImageSearchEx_Area(...): The main function with all available options.  
* _ImageSearch(...): A simplified wrapper for searching the entire screen.  
* _ImageInImageSearchEx_Area(...): Searches for an image within another image file.

### **Common Parameters**

| Parameter | Description | Default |
| :---- | :---- | :---- |
| $sImageFile | Path to the image(s). Use ` | ` to search for multiple images. |
| $iLeft, $iTop, $iRight, $iBottom | The coordinates of the search area. | Entire Screen |
| $iTolerance | Color tolerance (0-255). Higher values allow for more variation. | 10 |
| $iTransparent | A color in 0xRRGGBB format to be ignored during the search. | -1 (disabled) |
| $iMultiResults | The maximum number of results to return. | 1 |
| $iCenterPos | 1 returns the center coordinates; 0 returns the top-left. | 1 |
| $fMinScale, $fMaxScale | Minimum and maximum scaling factor (e.g., 0.8 for 80%). | 1.0 |
| $fScaleStep | The increment between scales (e.g., 0.1 for 10% steps). | 0.1 |
| $iFindAllOccurrences | 1 finds all matches; 0 stops after the first. | 0 |
| $iUseCache | 1 enables the file-based location cache; 0 disables it. | 1 |
| $iDisableAVX2 | 1 disables AVX2 optimization (for debugging). | 0 |

### **Return Value**

All search functions return a **2D array**.

* $aResult[0][0]: Contains the number of matches found.  
* For each match $i (from 1 to $aResult[0][0]):  
  * $aResult[$i][1]: X coordinate  
  * $aResult[$i][2]: Y coordinate  
  * $aResult[$i][3]: Width of the found image  
  * $aResult[$i][4]: Height of the found image

### **Utility Functions**

* _ImageSearchEx_GetVersion(): Returns the version string of the currently loaded DLL.  
* _ImageSearchEx_GetSysInfo(): Returns system info from the DLL (AVX2 support, screen resolution).  
* _ImageSearchEx_ClearCache(): Deletes all cache files from the temp directory.

## **6. For Developers: Compilation Guide**

If you need to recompile the DLLs, here are the required environments:

| DLL Version | Required Toolset | C++ Standard | Key Notes |
| :---- | :---- | :---- | :---- |
| **Modern (Win10+)** | Visual Studio 2022 (v143+) | C++23 | Requires the latest Windows SDK. Best for x64. |
| **Windows 7** | Visual Studio 2017+ (v141+) | C++14 | Must use the Windows 8.1 SDK. Produces the most compatible binary. |
| **Legacy (XP)** | Visual Studio 2010 (v100) | C++03 | Must use the Windows 7.1 SDK. Produces the most compatible binary. |

After compiling, place the DLLs in the same directory as the UDF with the correct filenames as defined in the UDF globals.
