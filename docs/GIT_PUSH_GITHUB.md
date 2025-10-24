# Git Workflow — Commit & Push lên GitHub

**Remote chính:** `git@github.com:Chinsusu/windows-automation.git`  
**Phạm vi:** Hướng dẫn chuẩn hoá thao tác commit/push cho dự án Automation (AutoIt + PowerShell + R2).

---

## 1) Chuẩn bị môi trường

### Cài Git (Windows)
- Tải **Git for Windows**: https://git-scm.com/download/win  
- Khi cài, giữ mặc định “Checkout Windows-style, commit Unix-style line endings” (hoặc xem mục EOL bên dưới).

### Cấu hình Git cơ bản
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

# Tuỳ chọn: đặt nhánh mặc định là main
git config --global init.defaultBranch main

# Windows EOL (khuyến nghị cho dự án này và PowerShell/AutoIt)
git config --global core.autocrlf true
```

> EOL khuyến nghị: `core.autocrlf true` giúp file script PowerShell/AutoIt dùng CRLF trên Windows, tránh lỗi khi chạy.

---

## 2) SSH với GitHub

### Tạo (hoặc dùng) SSH key
```bash
# sinh key (bấm Enter qua mỗi prompt để dùng mặc định)
ssh-keygen -t ed25519 -C "you@example.com"
# nếu máy không hỗ trợ ed25519:
# ssh-keygen -t rsa -b 4096 -C "you@example.com"
```

### Thêm key vào GitHub
- Copy public key:
  ```bash
  type ~/.ssh/id_ed25519.pub
  ```
- Dán vào GitHub > Settings > SSH and GPG keys > New SSH key.

### Kiểm tra kết nối
```bash
ssh -T git@github.com
# Expected: "Hi <username>! You've successfully authenticated..."
```

---

## 3) Khởi tạo repo cục bộ & kết nối remote

### A) Clone từ GitHub
```bash
git clone git@github.com:Chinsusu/windows-automation.git
cd windows-automation
```

### B) Đã có sẵn folder (đã tạo skeleton)
```bash
cd path\to\automation-skeleton-autoit-v1
git init
git remote add origin git@github.com:Chinsusu/windows-automation.git
# nếu trót thêm sai URL:
# git remote set-url origin git@github.com:Chinsusu/windows-automation.git
```

---

## 4) .gitignore & cấu trúc đầu ra

Đảm bảo repo có `.gitignore` (đã có trong skeleton):
```
/dist/
/db/
/logs/
*.exe
*.log
```

> Không commit: binary build, log runtime, DB runtime, secrets/token.

---

## 5) Quy ước commit & nhánh

### Conventional Commits (khuyến nghị)
- `feat:` chức năng mới
- `fix:` sửa lỗi
- `docs:` tài liệu
- `chore:` việc lặt vặt (build, deps…)
- `refactor:`, `test:`, `perf:`, `ci:`

### Quy ước nhánh
- `main`: ổn định phát hành
- `feat/<ten-tinh-nang>`: tính năng
- `fix/<ten-issue>`: sửa lỗi
- `docs/<noi-dung>`: tài liệu

---

## 6) Lần đầu commit & push

```bash
# kiểm tra trạng thái
git status

# thêm file
git add .

# commit theo quy ước
git commit -m "feat: bootstrap automation skeleton (AutoIt agent + server + scripts)"

# tạo nhánh main (nếu repo mới init)
git branch -M main

# push lên GitHub
git push -u origin main
```

---

## 7) Flow phát hành (tag + R2)

> Mục tiêu: Tag phiên bản, build agent, upload R2, cập nhật manifest & push.

### 7.1 Tạo tag phiên bản
```bash
# cập nhật version trong code/docs nếu có
git commit -am "chore(release): bump to 0.2.1"

# tạo annotated tag
git tag -a v0.2.1 -m "Release 0.2.1"
git push origin v0.2.1
```

### 7.2 Build & upload R2
- S3 endpoint (AWS CLI):
  ```powershell
  cd scripts
  ./compile_agent.ps1 0.2.1
  ./r2_upload.ps1 -Version 0.2.1 `
    -Bucket $env:R2_BUCKET `
    -AccountId $env:R2_ACCOUNT_ID `
    -AccessKey $env:AWS_ACCESS_KEY_ID `
    -SecretKey $env:AWS_SECRET_ACCESS_KEY
  ```
- Cloudflare Worker (Bearer token):
  ```powershell
  cd scripts
  ./r2_worker.ps1 -WorkerUrl $env:R2_WORKER_URL -AuthToken $env:R2_AUTH_TOKEN
  Upload-R2File -LocalPath "..\dist\AutoAgent-0.2.1.exe" -RemotePath "releases/AutoAgent-0.2.1.exe"
  ```

> `r2_upload.ps1` sẽ cập nhật `manifests/manifest.json`.  
> Với Worker, bạn tự sửa `manifests/manifest.json` tương ứng (hoặc viết step riêng để update).

### 7.3 Commit manifest & push
```bash
git add manifests/manifest.json
git commit -m "chore(release): publish 0.2.1 manifest"
git push
```

---

## 8) Cập nhật thường ngày

```bash
# tạo nhánh tính năng
git checkout -b feat/preset-commands

# code...

git add .
git commit -m "feat: add preset commands for OPEN_URL and CONTROL_CLICK"
git push -u origin feat/preset-commands

# mở Pull Request trên GitHub để review/merge vào main
```

---

## 9) Bảo mật

- Tuyệt đối không commit token: `R2_AUTH_TOKEN`, `AWS_SECRET_ACCESS_KEY`, v.v.
- Sử dụng biến môi trường hoặc GitHub Actions secrets nếu dùng CI.
- Kiểm tra `git log` và `git remote -v` trước khi push nếu repo công khai.

---

## 10) Troubleshooting

- Permission denied (publickey)  
  → Chưa add SSH key vào GitHub hoặc SSH agent chưa chạy.  
  Kiểm tra: `ssh -T git@github.com`

- Sai remote  
  ```bash
  git remote -v
  git remote set-url origin git@github.com:Chinsusu/windows-automation.git
  ```

- Cảnh báo line endings  
  → Bật `core.autocrlf true` (Windows) hoặc thêm `.gitattributes` nếu đa nền tảng.

- Lộ commit secret  
  → Xoá file, commit mới và rotate secret (đổi token ngay). Cần thiết dùng `git filter-repo` để xoá lịch sử.

---

## 11) Tham khảo nhanh (cheatsheet)

```bash
# xem thay đổi
git status
git diff

# add từng phần
git add -p

# sửa commit gần nhất (chưa push)
git commit --amend

# xem log gọn
git log --oneline --graph --decorate -n 20

# đổi nhánh
git checkout -b fix/callback-status

# merge nhanh (sau review)
git checkout main
git pull
git merge --no-ff fix/callback-status
git push
```

---

**Gợi ý:** Tập trung đọc `README.md` + `docs/R2_WORKER_API.md` để triển khai phát hành.  
**Remote:** `git@github.com:Chinsusu/windows-automation.git`  
**Nhắc lại:** Không commit token R2/AWS.

