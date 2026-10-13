# IT209 - Session 10 - Bài tập 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

- **Sinh viên:** Phạm Thanh Phong
- **MSSV:** N24DTCN120
- **Học phần:** IT209
- **Đường dẫn nộp bài:** `homework/session_10/ex4/`
- **Trạng thái:** Hoàn thành (100%)

---

## 1. Cấu trúc tệp tin dự án

| Tên tệp tin | Mô tả chức năng |
| :--- | :--- |
| [commands.sh](./commands.sh) | **Tệp thực thi nộp bài chính:** Script tự động hóa toàn bộ quy trình thiết lập hạ tầng mạng, volume, khởi chạy service và kiểm thử dữ liệu |
| [README.md](./README.md) | **Tệp báo cáo nộp bài chính thức:** Hướng dẫn, log đầu ra Terminal chi tiết, kiểm tra DNS resolution và Data Persistence |
| [IT209_Session10_BT4_PhamThanhPhong_N24DTCN120.md](./IT209_Session10_BT4_PhamThanhPhong_N24DTCN120.md) | Báo cáo kỹ thuật chuyên sâu về Embedded DNS Server của Docker và kiến trúc lưu trữ PostgreSQL Volume |

---

## 2. Toàn bộ các bước thực hiện & Nhật ký Terminal

### Bước 1: Khởi tạo Custom Bridge Network và Named Volume
Mạng bridge mặc định của Docker không hỗ trợ phân giải tên tự động (Automatic DNS Resolution), do đó cần tạo **Custom Bridge Network**:

```bash
# 1. Tạo mạng bridge tùy chỉnh
docker network create --driver bridge app-net

# 2. Tạo Named Volume cho PostgreSQL Database
docker volume create db-data
```

#### Kết quả đầu ra:
```plaintext
$ docker network create --driver bridge app-net
704c85d9f79f402487c3f0469111e20c6d2752b8b01dacccf7985a95794e6d83

$ docker volume create db-data
db-data
```

---

### Bước 2: Khởi chạy Database Container (PostgreSQL 15 Alpine)

Khởi chạy container `db-server` tham gia mạng `app-net` và mount volume `db-data` vào thư mục lưu trữ dữ liệu chuẩn của PostgreSQL `/var/lib/postgresql/data`:

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=SecretPassword123 \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine
```

#### Kết quả đầu ra:
```plaintext
Unable to find image 'postgres:15-alpine' locally
15-alpine: Pulling from library/postgres
da9db072f522: Already exists 
04665a933d89: Pull complete 
c5135d408574: Pull complete 
abda5d985228: Pull complete 
Digest: sha256:34274dcf72ec4a94ad4d5191e5c029587fe374cae9a94585a2a000fcb5028a47
Status: Downloaded newer image for postgres:15-alpine
477136cc4a6a4a8fae3f0d3a805d552438fa3343a2764a88a81bdda1ce6ee011
```

---

### Bước 3: Khởi chạy Backend Container trong cùng mạng `app-net`

```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=admin \
  -e DB_PASSWORD=SecretPassword123 \
  -e DB_NAME=app_db \
  alpine sleep 3600
```

#### Kết quả đầu ra:
```plaintext
2fafb711560a470daef59ed6742ded74917a77e684174e26a36be1564ae69d32
```

---

### Bước 4: Kiểm tra hạ tầng Docker CLI

#### 4.1. Kiểm tra Network và Volume trong danh sách:
```bash
docker network ls | grep app-net
docker volume ls | grep db-data
```
```plaintext
$ docker network ls | grep app-net
704c85d9f79f   app-net   bridge    local

$ docker volume ls | grep db-data
local     db-data
```

#### 4.2. Kiểm tra chi tiết cấu hình mạng bằng `docker network inspect app-net`:
```bash
docker network inspect app-net
```
```json
[
    {
        "Name": "app-net",
        "Id": "704c85d9f79f402487c3f0469111e20c6d2752b8b01dacccf7985a95794e6d83",
        "Created": "2026-10-13T10:34:10.1245812+07:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    "Gateway": "172.18.0.1"
                }
            ]
        },
        "Containers": {
            "477136cc4a6a...": {
                "Name": "db-server",
                "EndpointID": "5172b3c58bd8...",
                "MacAddress": "02:42:ac:12:00:02",
                "IPv4Address": "172.18.0.2/16",
                "IPv6Address": ""
            },
            "2fafb711560a...": {
                "Name": "app-container",
                "EndpointID": "69981b7a37db...",
                "MacAddress": "02:42:ac:12:00:03",
                "IPv4Address": "172.18.0.3/16",
                "IPv6Address": ""
            }
        }
    }
]
```

---

### Bước 5: Kiểm tra DNS Resolution (Ping theo tên service)

Thực hiện lệnh `ping` từ `app-container` tới `db-server` thông qua tên service:

```bash
docker exec -it app-container ping -c 2 db-server
```

#### Kết quả đầu ra Terminal:
```plaintext
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.082 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.076 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.076/0.079/0.082 ms
```

> **Đánh giá:** Docker Embedded DNS (`127.0.0.11`) đã tự động giải mã tên `db-server` thành địa chỉ IP nội bộ `172.18.0.2`, kết nối đạt 0% packet loss.

---

### Bước 6: Kiểm thử Data Persistence (Bảo toàn dữ liệu khi hủy Container)

#### 6.1. Tạo bảng và chèn dữ liệu mẫu vào `db-server`:
```bash
docker exec -i db-server psql -U admin -d app_db -c "
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (name) VALUES ('Pham Thanh Phong'), ('Docker Session 10');
SELECT * FROM users;
"
```

#### Kết quả đầu ra:
```plaintext
CREATE TABLE
INSERT 0 2
 id |       name        |         created_at         
----+-------------------+----------------------------
  1 | Pham Thanh Phong  | 2026-10-13 03:34:30.142857
  2 | Docker Session 10 | 2026-10-13 03:34:30.142857
(2 rows)
```

---

#### 6.2. Xóa cứng Container Database bằng cờ `-f` (Force):
```bash
docker rm -f db-server
```
```plaintext
db-server
```
*Xác nhận container `db-server` đã bị xóa hoàn toàn khỏi danh sách:*
```bash
docker ps -a --filter "name=db-server"
# Kết quả: CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES (Không còn tồn tại)
```

---

#### 6.3. Khởi tạo Container Database mới gắn cùng Volume `db-data`:
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=SecretPassword123 \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine
```
```plaintext
ad781507828847f894cb72a9587f954b5b84f0e20f7d411ab1b66b553ef13c75
```

---

#### 6.4. Xác minh dữ liệu không bị mất trên Container mới:
```bash
docker exec -i db-server psql -U admin -d app_db -c "SELECT * FROM users;"
```

#### Kết quả đầu ra Terminal:
```plaintext
 id |       name        |         created_at         
----+-------------------+----------------------------
  1 | Pham Thanh Phong  | 2026-10-13 03:34:30.142857
  2 | Docker Session 10 | 2026-10-13 03:34:30.142857
(2 rows)
```

> **Kết luận:** Mặc dù container `db-server` ban đầu bị xóa cưỡng chế, toàn bộ dữ liệu bảng `users` cùng các bản ghi của sinh viên **Phạm Thanh Phong** vẫn được bảo toàn nguyên vẹn 100% nhờ Named Volume `db-data`.

---

## 3. Bảng đối chiếu kết quả kiểm thử đề bài

| Tiêu chí kiểm tra | Lệnh thực hiện | Kết quả thực tế | Trạng thái |
| :--- | :--- | :--- | :---: |
| **Custom Network** | `docker network create ... app-net` | Mạng `app-net` driver bridge sẵn sàng | **PASS** |
| **Named Volume** | `docker volume create db-data` | Volume `db-data` driver local khởi tạo thành công | **PASS** |
| **Mount Volume DB** | `-v db-data:/var/lib/postgresql/data` | Gắn kết đúng thư mục data PostgreSQL | **PASS** |
| **DNS Resolution** | `docker exec app-container ping db-server` | Ping thành công IP `172.18.0.2`, 0% packet loss | **PASS** |
| **Test Data Persistence** | Thêm data -> Xóa DB -> Tạo lại -> Verify | Toàn bộ 2 bản ghi bảng `users` được bảo toàn | **PASS** |
| **Tệp tin nộp bài** | `commands.sh` và `README.md` | Đầy đủ mã script và tài liệu kiểm thử | **PASS** |
