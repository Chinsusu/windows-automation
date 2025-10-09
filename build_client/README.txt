================================================================================
    EARNAPP AUTO INSTALLER WITH SERVER CALLBACK
================================================================================

Công cụ tự động cài đặt EarnApp và gửi URL kích hoạt về server.

================================================================================
CẤU TRÚC FILE
================================================================================

EarnApp_Installer.exe    - File EXE chính để chạy (đã compile)
Main.au3                 - Script chính (source code)
Auto_Install.au3         - Script download và cài đặt EarnApp
Click_Skip.au3           - Script click nút Skip
Click_Signin.au3         - Script click nút Sign In
Copy_Url.au3             - Script copy URL và gửi về server
Image/                   - Thư mục chứa hình ảnh để ImageSearch
ImageSearchEx_UDF/       - Thư mục chứa DLL và UDF cho ImageSearch

================================================================================
CÁCH SỬ DỤNG
================================================================================

1. CẤU HÌNH SERVER URL
   - Mở file Main.au3
   - Tìm dòng 8: Global Const $SERVER_URL = "http://192.168.2.101:8080/cb"
   - Thay đổi IP và port thành server của bạn
   - Lưu file và compile lại (hoặc chỉnh luôn trong EXE nếu cần)

2. CHẠY TRÊN CLIENT
   - Copy toàn bộ thư mục "Install Earnapp" sang máy client
   - Chạy EarnApp_Installer.exe với quyền Administrator
   - Script sẽ tự động:
     + Download EarnApp từ earnapp.com
     + Cài đặt EarnApp
     + Click nút Skip
     + Click nút Sign In
     + Copy URL từ browser
     + Gửi URL về server qua HTTP POST

3. NHẬN DỮ LIỆU TỪ SERVER
   Server sẽ nhận POST request với JSON format:
   {
     "client_id": "client_XXXXXXXX",
     "status": "SUCCESS",
     "message": "https://earnapp.com/r/..."
   }

================================================================================
YÊU CẦU HỆ THỐNG
================================================================================

- Windows 7 trở lên (64-bit)
- Quyền Administrator
- Kết nối Internet
- AutoIt3 phải được cài đặt trên máy (để chạy các script .au3)
  Hoặc chỉ cần file EXE nếu đã compile

================================================================================
WORKFLOW HOẠT ĐỘNG
================================================================================

[Main.au3]
    |
    ├─> [STEP 1] Auto_Install.au3
    |      - Download earnapp-latest.exe
    |      - Cài đặt EarnApp
    |      - Chờ 10 giây để app khởi động
    |
    ├─> [STEP 2] Click_Skip.au3
    |      - Tìm cửa sổ EarnApp
    |      - Click nút Skip (góc trên phải)
    |      - Chờ 2 giây
    |
    ├─> [STEP 3] Click_Signin.au3
    |      - Tìm cửa sổ EarnApp
    |      - Click nút Sign In (góc dưới phải)
    |      - Chờ 10 giây để browser mở
    |
    └─> [STEP 4] Copy_Url.au3
           - Tìm Chrome browser window (class: Chrome_WidgetWin_1)
           - Focus vào address bar (Alt+D)
           - Copy URL (Ctrl+C)
           - Gửi URL về server qua HTTP POST
           - Client ID được tạo từ computer name

================================================================================
TROUBLESHOOTING
================================================================================

1. Nếu không tìm thấy cửa sổ EarnApp:
   - Kiểm tra EarnApp đã được cài đặt và khởi động chưa
   - Chờ thêm thời gian để app khởi động hoàn toàn

2. Nếu không copy được URL:
   - Kiểm tra browser window đã mở chưa
   - Thử chạy lại Copy_Url.au3 riêng

3. Nếu callback thất bại:
   - Kiểm tra server URL đúng chưa
   - Kiểm tra server đang chạy và có thể truy cập
   - Kiểm tra firewall

================================================================================
BUILD LẠI EXE
================================================================================

Nếu cần thay đổi code và build lại:

1. Chỉnh sửa file .au3
2. Chạy lệnh:
   "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe_x64.exe" /in "Main.au3" /out "EarnApp_Installer.exe" /comp 4

================================================================================
LƯU Ý
================================================================================

- Script cần quyền Admin để cài đặt EarnApp
- Tất cả các file .au3 phải ở cùng thư mục với EXE
- File config.ini sẽ tự động tạo và xóa trong quá trình chạy
- Server phải hỗ trợ POST request với Content-Type: application/json

================================================================================
LIÊN HỆ & HỖ TRỢ
================================================================================

Nếu gặp vấn đề, kiểm tra console output để debug.

Phiên bản: 1.0
Ngày tạo: 2025-10-08
