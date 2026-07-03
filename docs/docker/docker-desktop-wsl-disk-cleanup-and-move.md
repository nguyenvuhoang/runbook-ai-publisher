# Docker Desktop WSL: Dọn `docker_data.vhdx` và chuyển dữ liệu sang ổ SSD khác

## Overview

Trên Windows dùng Docker Desktop với WSL2, dung lượng Docker thường nằm trong file ổ đĩa ảo `docker_data.vhdx`, không phải Docker Hub.

File này chứa image local, container layer, build cache, network metadata và volume dữ liệu của container. Sau khi xóa image/cache/volume bằng Docker CLI, file `.vhdx` có thể vẫn giữ kích thước lớn cho đến khi được compact.

Ví dụ vị trí mặc định thường gặp:

```powershell
C:\Users\<USER>\AppData\Local\Docker\wsl\disk\docker_data.vhdx
```

Ví dụ khi đã chuyển sang ổ SSD mới:

```powershell
E:\1.ENVIRONMENT\DOCKER\DockerDesktopData\DockerDesktopWSL\disk\docker_data.vhdx
```

## When to use

Dùng runbook này khi gặp các tình huống sau:

- Ổ C bị đầy do Docker Desktop chiếm nhiều GB.
- `docker_data.vhdx` phình lớn dù đã push image lên Docker Hub.
- `docker system prune` báo reclaim `0B` nhưng file `.vhdx` vẫn lớn.
- Muốn chuyển Docker Desktop data sang ổ SSD khác như ổ `D:` hoặc `E:`.
- Muốn compact lại Docker WSL disk sau khi đã dọn image/cache/volume.

## Prerequisites

- Windows dùng Docker Desktop với WSL2 backend.
- PowerShell chạy quyền Administrator cho các lệnh `diskpart`, service và process.
- Đã xác định dữ liệu Docker local nào cần giữ.
- Cẩn thận với volume database local như SQL Server, PostgreSQL, Redis, RabbitMQ.

Không chạy lệnh xóa volume nếu còn cần dữ liệu database local.

## Steps

### 1. Kiểm tra file VHDX Docker đang nằm ở đâu

Chạy PowerShell:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Docker\wsl" -Recurse -Filter *.vhdx | Select-Object FullName,Length
```

Kết quả thường có dạng:

```text
C:\Users\nguye\AppData\Local\Docker\wsl\disk\docker_data.vhdx 63365447680
C:\Users\nguye\AppData\Local\Docker\wsl\main\ext4.vhdx          117440512
```

File cần quan tâm là `docker_data.vhdx`.

### 2. Kiểm tra Docker đang chiếm dung lượng ở đâu

```powershell
docker system df -v
```

Kiểm tra build cache:

```powershell
docker builder du
```

Kiểm tra volume:

```powershell
docker volume ls
```

### 3. Dọn Docker an toàn trước

Các lệnh này không xóa Docker volume database đang còn được Docker quản lý:

```powershell
docker container prune -f
docker image prune -a -f
docker builder prune -a -f
docker network prune -f
```

Nếu chắc chắn không cần dữ liệu volume local nữa thì mới chạy:

```powershell
docker volume prune -f
```

Dọn cực mạnh, bao gồm cả volume:

```powershell
docker system prune -a --volumes -f
```

Lưu ý: lệnh trên có thể làm mất dữ liệu database local trong volume.

### 4. Tắt Docker Desktop và WSL

Thoát Docker Desktop ở system tray, sau đó chạy PowerShell Administrator:

```powershell
wsl --shutdown
```

Kiểm tra trạng thái WSL:

```powershell
wsl -l -v
```

Kỳ vọng:

```text
Ubuntu            Stopped
Docker-desktop    Stopped
```

Tên distro có thể hiển thị là `docker-desktop`.

### 5. Kiểm tra process còn khóa file VHDX không

```powershell
Get-Process | Where-Object {
  $_.ProcessName -match "docker|wsl|vmmem"
} | Select-Object ProcessName,Id
```

Nếu còn các process như sau thì có thể chúng đang giữ lock file:

```text
com.docker.build
docker-agent
docker-sandbox
wslservice
vmmem
vmmemWSL
```

Dừng các process Docker còn sót:

```powershell
Stop-Process -Name "Docker Desktop","com.docker.backend","com.docker.build","docker-agent","docker-sandbox","docker","dockerd" -Force -ErrorAction SilentlyContinue
wsl --shutdown
```

Nếu cần restart service WSL:

```powershell
Restart-Service LxssManager -Force
wsl --shutdown
```

Nếu file vẫn bị khóa, restart Windows rồi chạy compact ngay, không mở Docker Desktop, Ubuntu hay VS Code trước.

### 6. Compact `docker_data.vhdx` bằng DiskPart

Với path mặc định trên ổ C:

```powershell
@"
select vdisk file="C:\Users\nguye\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@ | diskpart
```

Thay `nguye` bằng Windows user thật trên máy.

Không dùng placeholder nguyên văn như sau:

```powershell
C:\Users\<USER>\AppData\Local\Docker\wsl\disk\docker_data.vhdx
```

Vì ký tự `<USER>` chỉ là placeholder, DiskPart sẽ báo sai cú pháp.

Với path đã chuyển sang ổ E:

```powershell
@"
select vdisk file="E:\1.ENVIRONMENT\DOCKER\DockerDesktopData\DockerDesktopWSL\disk\docker_data.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@ | diskpart
```

Kết quả thành công thường có dòng:

```text
DiskPart successfully compacted the virtual disk file.
```

### 7. Kiểm tra lại dung lượng sau compact

Với path mặc định:

```powershell
Get-ChildItem "C:\Users\nguye\AppData\Local\Docker\wsl\disk\docker_data.vhdx" | Select-Object FullName,Length
```

Với path trên ổ E:

```powershell
Get-ChildItem "E:\1.ENVIRONMENT\DOCKER" -Recurse -Filter *.vhdx | Select-Object FullName,Length
```

## Chuyển Docker Desktop sang ổ SSD khác

### 1. Tạo thư mục mới trên ổ SSD

Ví dụ:

```powershell
New-Item -ItemType Directory -Force "E:\1.ENVIRONMENT\DOCKER\DockerDesktopData"
```

### 2. Đổi vị trí trong Docker Desktop

Mở Docker Desktop:

```text
Settings → Resources → Advanced → Disk image location
```

Chọn thư mục:

```text
E:\1.ENVIRONMENT\DOCKER\DockerDesktopData
```

Sau đó bấm:

```text
Apply & Restart
```

Docker Desktop sẽ tự chuyển nơi lưu Docker WSL disk sang ổ mới.

### 3. Kiểm tra sau khi chuyển

```powershell
Get-ChildItem "E:\1.ENVIRONMENT\DOCKER" -Recurse -Filter *.vhdx | Select-Object FullName,Length
```

Kết quả mong muốn:

```text
E:\1.ENVIRONMENT\DOCKER\DockerDesktopData\DockerDesktopWSL\disk\docker_data.vhdx
E:\1.ENVIRONMENT\DOCKER\DockerDesktopData\DockerDesktopWSL\main\ext4.vhdx
```

Kiểm tra ổ C không còn file Docker WSL cũ:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Docker\wsl" -Recurse -Filter *.vhdx | Select-Object FullName,Length
```

Nếu không trả kết quả là Docker data đã được chuyển khỏi ổ C.

## Verification

### Kiểm tra Docker object hiện tại

```powershell
docker system df -v
```

### Kiểm tra VHDX hiện nằm trên ổ mới

```powershell
Get-ChildItem "E:\1.ENVIRONMENT\DOCKER" -Recurse -Filter *.vhdx | Select-Object FullName,Length
```

Ví dụ dung lượng sau khi chuyển thành công:

```text
E:\1.ENVIRONMENT\DOCKER\DockerDesktopData\DockerDesktopWSL\disk\docker_data.vhdx 3349151744
E:\1.ENVIRONMENT\DOCKER\DockerDesktopData\DockerDesktopWSL\main\ext4.vhdx         142606336
```

### Kiểm tra ổ C không còn Docker VHDX

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Docker\wsl" -Recurse -Filter *.vhdx | Select-Object FullName,Length
```

Không có output là tốt.

## Common errors

### DiskPart báo sai cú pháp path

Lỗi:

```text
DiskPart has encountered an error: The filename, directory name, or volume label syntax is incorrect.
```

Nguyên nhân thường gặp là copy nguyên placeholder:

```powershell
C:\Users\<USER>\AppData\Local\Docker\wsl\disk\docker_data.vhdx
```

Cách xử lý: lấy path thật bằng lệnh:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Docker\wsl" -Recurse -Filter *.vhdx | Select-Object FullName,Length
```

Sau đó dùng path thật trong DiskPart.

### DiskPart báo file đang được process khác sử dụng

Lỗi:

```text
The process cannot access the file because it is being used by another process.
```

Cách xử lý:

```powershell
wsl --shutdown
Stop-Process -Name "Docker Desktop","com.docker.backend","com.docker.build","docker-agent","docker-sandbox","docker","dockerd" -Force -ErrorAction SilentlyContinue
Restart-Service LxssManager -Force
wsl --shutdown
```

Kiểm tra lại process:

```powershell
Get-Process | Where-Object {
  $_.ProcessName -match "docker|wsl|vmmem"
} | Select-Object ProcessName,Id
```

Nếu vẫn bị khóa, restart Windows và chạy compact ngay trước khi mở Docker Desktop/WSL.

### Docker prune báo `0B` nhưng file VHDX vẫn lớn

Đây là bình thường. Docker CLI đã xóa object logic, nhưng Windows VHDX chưa thu nhỏ vật lý. Cần chạy `diskpart compact vdisk`.

### Docker Desktop không move data sang ổ mới

Nếu đổi `Disk image location` không thành công hoặc Docker vẫn dùng ổ C:

1. Đảm bảo Docker Desktop đã Apply & Restart.
2. Kiểm tra lại file `.vhdx` ở ổ mới.
3. Nếu vừa prune sạch và không cần giữ local data, có thể dùng:
   - Docker Desktop → Settings → Troubleshoot → Clean / Purge data
   - hoặc Reset to factory defaults
4. Sau reset, chọn lại `Disk image location` trên ổ SSD mới trước khi pull/build lại image.

## Notes

- Docker Hub là cloud registry, không liên quan trực tiếp đến dung lượng `docker_data.vhdx` trên máy local.
- Image đã push lên Docker Hub vẫn có thể còn bản local và build cache trên máy.
- `docker_data.vhdx` không tự nhỏ lại ngay sau khi xóa image/cache/volume.
- Không nên xóa trực tiếp file `docker_data.vhdx` khi Docker Desktop hoặc WSL còn đang chạy.
- Nếu cần xóa thủ công, nên rename file trước, mở Docker Desktop cho tạo file mới, kiểm tra ổn rồi mới xóa file cũ.
- Tránh chạy `docker system prune -a --volumes -f` nếu còn database local cần giữ.

## Tags

- docker
- docker-desktop
- wsl2
- windows
- vhdx
- diskpart
- compact-vdisk
- storage-cleanup
