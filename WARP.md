# WARP.md — Project Rules (Automation: Windows + AutoIt + R2)

## Mục tiêu dự án
- Hệ thống automation với **1-file Agent** (AutoIt) chạy nền trên Windows 10.
- **Server (Windows 10/Server 2019/2022)** viết **AutoIt + GUI**, build agent, xuất bản lên **Cloudflare R2**, nhận callback và giao nhiệm vụ cho client qua HTTP.
- Quản lý client theo `client_id`/IP, lưu trạng thái và log vào **SQLite**.

## Phạm vi & Ngữ cảnh cho Agent của Warp
- Khi tạo lệnh / gợi ý code, **ưu tiên PowerShell** trên Windows, **không** dùng `bash` trừ khi chỉ định.
- Đường dẫn Windows dùng `C:\ProgramData\AutoAgent\` cho agent & logs.
- Các thao tác release **không** nhúng token vào code; token lấy từ biến môi trường.

## Quy ước code & build
- **AutoIt**: tách module, **≤ 500 dòng / file**. Đặt tên:
  - Hàm public: PascalCase; biến local: camelCase; hằng: UPPER_SNAKE.
- **Logging**: mọi hành động có `trace_id` ngắn; log file: `%ProgramData%\AutoAgent\agent.log` (client) và `logs\server.log` (server).
- **Versioning**: `MAJOR.MINOR.PATCH`, nhúng vào agent và manifest R2.
- **Build agent**: dùng `Aut2Exe` (x64), script `scripts/compile_agent.ps1`.
- **Manifest/R2**: dùng `scripts/r2_upload.ps1` (S3 endpoint) **hoặc** `scripts/r2_worker.ps1` (Cloudflare Worker, Bearer).

## R2 (release) — bắt buộc
- Lấy cấu hình từ ENV:
  - `R2_WORKER_URL`, `R2_AUTH_TOKEN` (Worker)
  - Hoặc `R2_ACCOUNT_ID`, `R2_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (S3-compatible)
- **Không commit token**. Nếu cần ví dụ cURL/PowerShell, chỉ minh họa, không dán bí mật thật.

## Tiêu chuẩn lệnh thao tác máy khách
- Ưu tiên `ControlClick`/`ControlSend` thay vì click tọa độ.
- Không chạy lệnh gây gián đoạn hệ thống nếu không có xác nhận rõ.
- Khi tải file: kiểm `sha256` nếu có trong manifest trước khi swap.
- Update agent zero-downtime qua Scheduled Task “AutoAgent-Update”.

## Cách agent tương tác
- Long-poll `GET /tasks?client_id=...` (timeout 10–25s), gửi `POST /cb` (status, message) và `POST /task_result`.
- Nếu network lỗi: backoff luỹ thừa tối đa 60s; không spam server.

## Tiêu chuẩn commit/PR (khuyến nghị)
- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, …
- Mọi PR phải đính kèm: phạm vi module, thay đổi schema/manifest nếu có, và checklist test (build, update, lệnh preset).

## Môi trường & Công cụ
- Windows: PowerShell 5+; AutoIt + Aut2Exe; SQLite; AWS CLI hoặc rclone (nếu dùng S3).
- Lưu ý mã hóa: UTF-8, CRLF cho script PowerShell; AutoIt mặc định ANSI/UTF-8 tùy file.

## Quy trình phát hành mẫu
1) `./scripts/compile_agent.ps1 0.2.1`
2) Upload:
   - Worker: `./scripts/r2_worker.ps1 -WorkerUrl $env:R2_WORKER_URL -AuthToken $env:R2_AUTH_TOKEN` → `Upload-R2File -LocalPath dist\AutoAgent-0.2.1.exe -RemotePath releases/AutoAgent-0.2.1.exe`
   - hoặc S3: `./scripts/r2_upload.ps1 -Version 0.2.1 -Bucket $env:R2_BUCKET -AccountId $env:R2_ACCOUNT_ID -AccessKey $env:AWS_ACCESS_KEY_ID -SecretKey $env:AWS_SECRET_ACCESS_KEY`
3) Cập nhật `manifests\manifest.json` (script tự ghi).
4) Gửi `UPDATE_AGENT` hoặc chờ auto-update (10 phút/lần).

## “Do / Don’t”
- ✅ Do: tách module nhỏ, mỗi file ≤ 500 dòng; log đủ, có trace_id; checksum file tải.
- ✅ Do: dùng biến môi trường cho bí mật; viết script idempotent.
- ❌ Don’t: hardcode token/URL nội bộ; click theo tọa độ khi có thể dùng control; chạy lệnh destructive.
