# Automation Skeleton (Windows + AutoIt) — v1
Minimal repo để bắt đầu hệ thống automation: 1-file Agent (AutoIt) + Server GUI (AutoIt),
build agent -> upload Cloudflare R2, quản lý client bằng SQLite.

> Đây là skeleton có thể mở rộng. Các API/JSON hiện stub để bạn plug-in nhanh phần thực thi.

## Cấu trúc
```
automation-skeleton-autoit-v1/
  agent/                 # 1-file Agent (tách module, mỗi file < 500 dòng)
  server/                # Server GUI + HTTP listener + SQLite
  scripts/               # PowerShell build & upload R2
  docs/                  # Protocol/Commands/Operations
  manifests/             # manifest.json (release index)
  db/                    # SQLite runtime (tạo tự động)
  logs/                  # logs runtime
  dist/                  # output agent .exe (sau khi build)
```
## Yêu cầu
- Windows 10/Server 2019/2022
- AutoIt + Aut2Exe
- (Tuỳ chọn) AWS CLI hoặc rclone cho Cloudflare R2

## Nhanh: build Agent
```powershell
cd scripts
./compile_agent.ps1 0.2.0   # tạo dist/AutoAgent-0.2.0.exe
```

## Nhanh: upload R2 + cập nhật manifest
```powershell
cd scripts
./r2_upload.ps1 -Version 0.2.0 -Bucket YOUR_BUCKET -AccountId YOUR_ACCOUNT_ID -AccessKey AKIA... -SecretKey ********
```

## Chạy Server GUI
- Mở `server/server_gui.au3` bằng SciTE, chạy F5 để thử GUI.
- Listener & DB là stub: bổ sung thực thi trong `server_http_listener.au3` và `server_db.au3`.

## Agent cài đặt lần đầu (1 file duy nhất)
```bat
mkdir C:\ProgramData\AutoAgent 2>nul
copy dist\AutoAgent-0.2.0.exe C:\ProgramData\AutoAgent\AutoAgent.exe
schtasks /Create /TN "AutoAgent" /TR "C:\ProgramData\AutoAgent\AutoAgent.exe /service" /SC ONSTART /RU SYSTEM /RL HIGHEST /F
schtasks /Create /TN "AutoAgent-Logon" /TR "C:\ProgramData\AutoAgent\AutoAgent.exe /service" /SC ONLOGON /RU SYSTEM /RL HIGHEST /F
schtasks /Run /TN "AutoAgent"
```

## Lưu ý
- Các module giữ dưới 500 dòng để dễ review.
- JSON/HTTP hiện ở mức tối thiểu (stub) nhằm đảm bảo compile dễ. Bạn có thể dùng WinHttp.au3 và JSON UDF sau.


## R2 (Cloudflare) cho phát hành
- Dùng endpoint S3 (AWS CLI) → `scripts/r2_upload.ps1`
- **Hoặc** dùng Cloudflare Worker (Bearer token) → xem `docs/R2_WORKER_API.md` và script `scripts/r2_worker.ps1`
