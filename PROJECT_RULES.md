# PROJECT_RULES — Quy tắc & Chuẩn hoá

Tài liệu này tổng hợp quy ước cho toàn bộ repo (Agent AutoIt, Server GUI, scripts phát hành, tài liệu). Mục tiêu: dễ bảo trì, phát hành nhất quán, tránh rác/binary, và giữ an toàn bảo mật.

## 1) Phạm vi & Mục tiêu
- Áp dụng cho toàn bộ repo: AutoIt, PowerShell, tài liệu, và (tùy chọn) server viết bằng Go.
- Ưu tiên: cấu trúc rõ ràng, tách nhỏ theo chức năng, mỗi file ≤ 500 dòng để dễ review/nâng cấp.
- Không commit artefact build, DB/runtime, log, hoặc secrets.

## 2) Cấu trúc thư mục chuẩn
- `agent/` 1-file Agent chia module nhỏ (AutoIt): `agent_main.au3`, `agent_http.au3`, `agent_commands.au3`, `agent_config.au3`, `agent_util.au3`, `agent_updater.au3`.
- `server/` Server GUI + HTTP listener + SQLite (AutoIt).
- `scripts/` PowerShell: build (`compile_agent.ps1`), phát hành R2 (S3/Worker) (`r2_upload.ps1`, `r2_worker.ps1`).
- `docs/` Tài liệu giao thức, lệnh, vận hành, phát hành (`COMMANDS.md`, `PROTOCOL.md`, `OPERATIONS.md`, `R2_WORKER_API.md`, ...).
- `manifests/` Chứa `manifest.json` mô tả bản phát hành mới nhất cho Agent.
- `dist/` Đầu ra build (exe) — bị ignore trong Git.
- `db/`, `logs/` Runtime — bị ignore trong Git.
- (Tuỳ chọn) `server_go/` cho server viết bằng Go (xem mục 6C).

## 3) Build & Artefacts (build file vào đâu)
- Build Agent: dùng `scripts/compile_agent.ps1 <version>` → xuất ra `dist/AutoAgent-<version>.exe`.
- Phát hành R2:
  - S3 endpoint (AWS CLI): `scripts/r2_upload.ps1` đồng thời cập nhật `manifests/manifest.json`.
  - Cloudflare Worker (Bearer token): `scripts/r2_worker.ps1` (upload) và tự cập nhật `manifest.json` thủ công hoặc qua script riêng.
- Tuyệt đối KHÔNG commit file trong `dist/`, `db/`, `logs/`, `*.exe`, `*.log` (đã có `.gitignore`).

## 4) Tổ chức mã nguồn (chia nhỏ file theo function, ≤ 500 dòng)
- Single Responsibility: mỗi file/module phục vụ 1 nhóm chức năng rõ ràng (HTTP, commands, config, updater, util...).
- Giới hạn độ dài: mỗi file ≤ 500 dòng. Nếu vượt, tách module:
  - Ví dụ: tách `agent_commands_*` theo nhóm lệnh (UI, shell, download...).
  - Với server, tách `server_http_listener` vs `server_db` vs `server_gui*` rõ ràng.
- API nội bộ rõ ràng: chỉ export hàm cần dùng giữa module; phần còn lại để nội bộ.
- Đặt tên nhất quán:
  - Tên file: snake_case, mô tả chức năng (vd: `server_http_listener.au3`).
  - Tên hàm: PascalCase/CamelCase theo phong cách hiện có của dự án (giữ nguyên tính nhất quán nội bộ từng file).
  - Hằng số/biến cấu hình: viết HOA có prefix gợi nhớ (vd: `$CFG_ServerUrl`).
- Comment tối thiểu, tự miêu tả: mô tả đầu hàm, tham số, side-effects.

## 5) Encoding, EOL, định dạng
- EOL: CRLF (Windows). Git khuyến nghị `core.autocrlf true` để tránh lỗi khi chạy script trên Windows.
- Encoding: Ưu tiên UTF-8 (BOM khi cần với AutoIt/SciTE). Tránh dùng mã hóa lẫn lộn.
- Định dạng:
  - AutoIt: thụt dòng nhất quán (2–4 spaces), block rõ ràng.
  - PowerShell: PascalCase cho hàm/cmdlet; tham số ghi rõ kiểu khi hợp lý.
  - Markdown: tiêu đề chuẩn H1..H3, danh sách gọn, code block kèm ngôn ngữ.

## 6) Ngôn ngữ & Layout
### A) AutoIt (Agent/Server GUI)
- Giữ module nhỏ: HTTP, Commands, Config, Updater, Util.
- Tránh global không cần thiết; gom config qua 1 module config.
- Giao tiếp mạng dùng WinHttp/JSON UDF; retry hợp lý; log sự kiện quan trọng.

### B) PowerShell (scripts/)
- Script có `Param(...)` đầu file; `Write-Error`/`throw` khi điều kiện thiếu.
- Không ghi secrets vào repo; dùng biến môi trường cho token/keys.
- Đường dẫn dùng `Join-Path` để an toàn.

### C) Go (tuỳ chọn) — “path golang ở đâu”
- Nếu bổ sung server bằng Go, đặt tại `server_go/` với layout chuẩn module:
  ```
  server_go/
    cmd/server/main.go      # entrypoint server
    internal/http/          # HTTP handlers, middleware
    internal/db/            # truy cập DB (SQLite/khác)
    internal/core/          # nghiệp vụ
    go.mod                  # module path (cập nhật theo repo thực tế)
  ```
- Dùng Go Modules (không phụ thuộc GOPATH). Ví dụ module: `module github.com/<org>/windows-automation/server_go`.
- Build output: `server_go/bin/automation-server.exe` (bị ignore). Ví dụ:
  - `go build -o server_go/bin/automation-server.exe ./cmd/server`
- Cấu hình: qua biến môi trường `.env` hoặc flags, không commit secrets.

## 7) Giao thức & Manifest
- Client long-poll `GET /tasks?client_id=...` (timeout 10–25s), callback `POST /cb`.
- Header `X-Api-Key` bắt buộc cho mọi request từ agent/client.
- Endpoint `/agent/latest` đọc từ `manifests/manifest.json`.
- `manifests/manifest.json` tối thiểu gồm: `latest`, `url`, (khuyến khích) `sha256`, kích thước, thời điểm phát hành.

## 8) Quy trình Git & Nhánh
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `perf:`, `ci:`.
- Nhánh: `main` (ổn định phát hành), `feat/<tinh-nang>`, `fix/<ten-issue>`, `docs/<noi-dung>`, ...
- Không commit: `dist/`, `db/`, `logs/`, `*.exe`, `*.log`, secrets/tokens.

## 9) Bảo mật
- Tuyệt đối KHÔNG commit token/secret (R2/AWS/Worker). Dùng biến môi trường hoặc Secrets của CI.
- Xem lại `git remote -v` và `git log` trước khi push nếu repo công khai.
- Nếu lỡ commit secret: xóa, rotate secret ngay, và dùng công cụ rewrite history (vd: `git filter-repo`) khi cần.

## 10) Rác & dọn dẹp (xóa file rác)
- Quy định “rác build/runtime” (đã ignore): `dist/`, `db/`, `logs/`, `*.exe`, `*.log`, `/.warp/`.
- Dọn rác build theo Git (cẩn trọng):
  - Xem trước: `git clean -Xnd` (chỉ liệt kê file bị ignore sẽ bị xóa).
  - Thực thi: `git clean -Xdf` (xóa file bị ignore). Luôn kiểm tra kỹ trước khi chạy.
- Ứng viên “khả nghi” nên chuẩn hoá/tên lại hoặc xóa nếu trùng/nhân bản:
  - `scripts/InstallEarnapp/5_ClickAccept_Invite_CloseApp.au3.au3`
  - `scripts/InstallEarnapp/6_ActivatePopup_ChooseNote_Minimize.au3.au3`
  (Đây có vẻ là đuôi `.au3` lặp. Cần xác minh trước khi xóa.)

## 11) Phát hành (Release) — tóm tắt
1) Bump version trong code/docs nếu có; tag: `vX.Y.Z`.
2) Build Agent: `scripts/compile_agent.ps1 X.Y.Z` → `dist/AutoAgent-X.Y.Z.exe`.
3) Upload R2:
   - S3 endpoint: `scripts/r2_upload.ps1 -Version X.Y.Z -Bucket ... -AccountId ... -AccessKey ... -SecretKey ...` (script này cập nhật `manifests/manifest.json`).
   - Worker: dùng `scripts/r2_worker.ps1` và cập nhật `manifests/manifest.json` tương ứng.
4) Commit `manifests/manifest.json` (không commit binary).

## 12) Checklist nhanh
- [ ] File/module ≤ 500 dòng, 1 trách nhiệm.
- [ ] Không thêm artefact vào Git; `.gitignore` vẫn hiệu lực.
- [ ] EOL CRLF, encoding UTF-8 (BOM khi cần cho AutoIt).
- [ ] Secrets chỉ ở biến môi trường/CI Secrets.
- [ ] Build ra `dist/`; cập nhật `manifests/manifest.json` khi phát hành.
- [ ] Tài liệu cập nhật khi thay đổi giao thức/lệnh.

