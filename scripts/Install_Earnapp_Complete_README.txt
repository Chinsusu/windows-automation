==========================================
HƯỚNG DẪN SỬ DỤNG INSTALL_EARNAPP_COMPLETE
==========================================

TỔNG QUAN:
----------
Script này tự động hóa toàn bộ quá trình cài đặt Earnapp và lấy URL:
1. Download installer từ earnapp.com
2. Cài đặt Earnapp (silent hoặc GUI automation)
3. Click nút "Sign In" trong app
4. Click nút "Skip" (nếu có)
5. Lấy URL từ browser
6. Gửi URL về server qua HTTP callback

CẤU HÌNH:
---------
Trước khi sử dụng, CẦN SỬA dòng 13 trong script:

    Global Const $SERVER_URL = "http://192.168.2.101:8080/cb"
    
Thay "192.168.2.101" bằng IP thực tế của server bạn.

CÁCH SỬ DỤNG:
-------------

OPTION 1: Copy script qua client và chạy trực tiếp
---------------------------------------------------
1. Copy file "Install_Earnapp_Complete.au3" vào client machine
2. Chạy script với quyền Administrator:
   - Right-click -> Run as Administrator (nếu đã compile)
   - Hoặc: AutoIt3.exe Install_Earnapp_Complete.au3

OPTION 2: Gửi qua automation system (KHUYẾN NGHỊ)
--------------------------------------------------
1. Upload script lên server R2 hoặc web server
2. Từ GUI server, gửi command đến client:
   
   DOWNLOAD_FILE {"url":"http://your-server/Install_Earnapp_Complete.au3","path":"C:\\Temp\\install.au3"}
   
3. Sau đó gửi command thực thi:
   
   SHELL {"cmd":"AutoIt3.exe C:\\Temp\\install.au3"}

OPTION 3: Tích hợp vào agent command
-------------------------------------
Thêm command type mới vào agent_commands.au3:

    Case "INSTALL_EARNAPP"
        ; Download script
        ; Execute script
        Return "Installing..."

KẾT QUẢ:
--------
Khi script chạy thành công, server sẽ nhận callback với:
- status: "SUCCESS" 
- message: URL của Earnapp (ví dụ: https://earnapp.com/r/sdk-xxxxx)

Nếu thất bại:
- status: "FAILED"
- message: Mô tả lỗi (Download failed, Installation failed, etc.)

LOG:
----
Script sẽ in progress ra console:
[1/5] Downloading installer...
[OK] Downloaded to: C:\Users\...\Desktop\earnapp-latest.exe
[2/5] Installing Earnapp...
[OK] Installation completed
[3/5] Clicking Sign In...
[OK] Sign In clicked
[4/5] Looking for Skip button...
[OK] Skip handled
[5/5] Getting URL...
[OK] URL: https://earnapp.com/r/...
[CALLBACK] Sending to server: https://earnapp.com/r/...
[CALLBACK] Success
=== COMPLETED ===

LƯU Ý:
-------
- Script yêu cầu quyền Administrator (để cài đặt ứng dụng)
- Thời gian chạy: ~2-5 phút tùy tốc độ mạng và máy
- Script sẽ tự động xử lý các popup cài đặt
- Không cần ImageSearch DLL - chỉ dùng pure AutoIt
- Script sẽ không đóng browser sau khi lấy URL (để user có thể sử dụng tiếp)

TROUBLESHOOTING:
----------------
Nếu script failed:
1. Kiểm tra kết nối internet
2. Kiểm tra firewall không chặn download/callback
3. Kiểm tra antivirus không block script
4. Chạy thử manual từng bước để debug
5. Xem log file (nếu có) hoặc console output

THAY ĐỔI CẤU HÌNH:
-------------------
Có thể điều chỉnh timeout trong script:
- $MAX_WAIT_INSTALL = 300 (giây) - timeout cài đặt
- $MAX_WAIT_BROWSER = 60 (giây) - timeout chờ browser
- $MAX_WAIT_SIGNIN = 30 (giây) - timeout chờ app Sign In

==========================================
