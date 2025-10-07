# WARP.md — Agent (AutoIt)

## Nguyên tắc
- Viết AutoIt theo module: `agent_main.au3`, `agent_http.au3`, `agent_commands.au3`, `agent_updater.au3`, `agent_util.au3`, `agent_config.au3`.
- Mỗi file **≤ 500 dòng**.
- Tất cả API call phải kèm header `X-Api-Key` (đọc từ config/ENV), log request + response status (không log token).

## Lệnh chuẩn agent phải hỗ trợ
- `OPEN_URL`, `RUN`, `SHELL`, `CLICK`, `CONTROL_CLICK`, `TYPE_TEXT`, `KEYSEQ`, `DOWNLOAD_FILE`, `SLEEP`, `UPDATE_AGENT`.

## Cập nhật agent
- Kiểm tra phiên bản 10 phút/lần qua `/agent/latest`.
- Tải bản mới về `AutoAgent.new.exe`, verify `sha256`, swap qua Scheduled Task `AutoAgent-Update`, sau đó khởi chạy lại `AutoAgent`.
