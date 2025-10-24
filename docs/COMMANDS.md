# COMMANDS

| Type           | Args (JSON)                                             | Mô tả                          |
|----------------|----------------------------------------------------------|--------------------------------|
| OPEN_URL       | { "url": "https://..." }                               | Mở URL bằng trình duyệt mặc định |
| RUN            | { "path": "C:\\app.exe", "args":"", "wait":true }   | Chạy chương trình              |
| SHELL          | { "cmd": "ipconfig /all" }                             | Chạy lệnh shell                |
| CLICK          | { "x":100, "y":200, "button":"left", "times":1 }     | Click tọa độ                   |
| CONTROL_CLICK  | { "title":"Untitled - Notepad", "class":"Button1" }   | Click theo control             |
| TYPE_TEXT      | { "text":"hello", "raw":false }                        | Gõ phím                        |
| KEYSEQ         | { "seq":"^a^c" }                                       | Tổ hợp phím                    |
| DOWNLOAD_FILE  | { "url":"https://...", "dst":"C:\\file" }            | Tải file                       |
| SLEEP          | { "ms": 1000 }                                          | Tạm dừng                       |
| UPDATE_AGENT   | { "version": "0.2.1" }                                  | Áp dụng cập nhật               |

