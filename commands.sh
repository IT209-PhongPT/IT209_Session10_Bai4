#!/usr/bin/env bash
# ==============================================================================
# Script thực thi Bài tập 4 - Session 10: Custom Network & Named Volume
# Sinh viên: Phạm Thanh Phong - MSSV: N24DTCN120
# Học phần: IT209
# ==============================================================================

set -e

echo "=== [1] KHỞI TẠO CUSTOM BRIDGE NETWORK & NAMED VOLUME ==="
# 1. Tạo Custom Bridge Network để các container tự phân giải DNS theo tên
docker network create --driver bridge app-net

# 2. Tạo Named Volume lưu trữ dữ liệu bền vững
docker volume create db-data

echo ""
echo "=== [2] KHỞI CHẠY DATABASE CONTAINER (POSTGRESQL) ==="
# 3. Khởi chạy Database container gắn kết volume db-data và mạng app-net
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=SecretPassword123 \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine

# Chờ database sẵn sàng nhận kết nối
echo "Đang đợi PostgreSQL khởi động..."
sleep 5

echo ""
echo "=== [3] KHỞI CHẠY BACKEND CONTAINER ==="
# 4. Khởi chạy Backend container tham gia app-net, truyền cấu hình DB hostname
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=admin \
  -e DB_PASSWORD=SecretPassword123 \
  -e DB_NAME=app_db \
  alpine sleep 3600

echo ""
echo "=== [4] KIỂM TRA PHÂN GIẢI DNS NỘI BỘ (PING THEO TÊN SERVICE) ==="
# 5. Kiểm tra DNS resolution: Backend container ping tới db-server bằng tên
docker exec app-container ping -c 2 db-server

echo ""
echo "=== [5] THỰC HIỆN TEST DATA PERSISTENCE ==="
# 6. Tạo bảng và chèn dữ liệu mẫu vào PostgreSQL
echo "-> Tạo bảng 'users' và thêm 2 bản ghi..."
docker exec -i db-server psql -U admin -d app_db << 'EOF'
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (name) VALUES ('Pham Thanh Phong'), ('Docker Session 10');
SELECT * FROM users;
EOF

echo ""
echo "-> XÓA CỨNG CONTAINER DB BẰNG LỆNH (docker rm -f db-server)..."
docker rm -f db-server

echo ""
echo "-> KHỞI TẠO CONTAINER DB MỚI GẮN CÙNG VOLUME db-data..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=SecretPassword123 \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine

sleep 5

echo ""
echo "-> XÁC MINH DỮ LIỆU VẪN TỒN TẠI NGUYÊN VẸN TRÊN CONTAINER MỚI:"
docker exec -i db-server psql -U admin -d app_db -c "SELECT * FROM users;"

echo ""
echo "=== BÀI TẬP 4 ĐÃ HOÀN TẤT THÀNH CÔNG 100% ==="
