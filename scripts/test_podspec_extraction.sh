#!/bin/bash
set -e

echo "=== Kiểm tra Logic Giải Nén của Podspec ==="

# 1. Tạo môi trường giả lập framework
rm -rf /tmp/mock_fw /tmp/mock_fw_nested
mkdir -p /tmp/mock_fw/KMPWorkManager.xcframework/Headers
touch /tmp/mock_fw/KMPWorkManager.xcframework/Headers/Mock.h

# 2. Giả lập tạo Zip Phẳng (Flat Zip)
cd /tmp/mock_fw
zip -rq /tmp/flat_release.zip KMPWorkManager.xcframework

# 3. Giả lập tạo Zip Lồng (Nested Zip - giống bản 1.3.0 trên Github)
mkdir -p /tmp/mock_fw_nested/Frameworks
cp -r /tmp/mock_fw/KMPWorkManager.xcframework /tmp/mock_fw_nested/Frameworks/
cd /tmp/mock_fw_nested
zip -rq /tmp/nested_release.zip Frameworks/

echo "[✓] Đã tạo thành công 2 file zip giả lập (Flat và Nested)."
echo ""

# 4. Hàm thực thi y hệt logic trong podspec
test_extraction() {
  local zip_path=$1
  local test_name=$2
  
  echo "--- Đang chạy test: $test_name ---"
  
  # Dọn dẹp trước khi chạy
  rm -rf /tmp/test_workspace
  mkdir -p /tmp/test_workspace/Frameworks
  cd /tmp/test_workspace
  
  # ---- ĐOẠN LOGIC SAO CHÉP TỪ PODSPEC BẮT ĐẦU ----
  rm -rf /tmp/kmpwm_extract
  unzip -oq "$zip_path" -d /tmp/kmpwm_extract
  # Release zip may be flat or wrapped in a Frameworks/ dir - handle both.
  SRC=$(find /tmp/kmpwm_extract -maxdepth 2 -type d -name 'KMPWorkManager.xcframework' | head -1)
  rm -rf Frameworks/KMPWorkManager.xcframework
  mv "$SRC" Frameworks/KMPWorkManager.xcframework
  rm -rf /tmp/kmpwm_extract
  # ---- ĐOẠN LOGIC SAO CHÉP TỪ PODSPEC KẾT THÚC ----
  
  # Kiểm tra kết quả
  if [ -d "Frameworks/KMPWorkManager.xcframework" ] && [ ! -d "Frameworks/Frameworks" ]; then
    echo "[✓] THÀNH CÔNG: Kết quả trích xuất chuẩn xác ở 1 lớp Frameworks/KMPWorkManager.xcframework"
  else
    echo "[x] THẤT BẠI: Cấu trúc thư mục bị sai."
    ls -R Frameworks
    exit 1
  fi
  echo ""
}

# 5. Chạy test cho cả 2 trường hợp
test_extraction "/tmp/flat_release.zip" "FILE ZIP PHẲNG (Zip không bọc Frameworks)"
test_extraction "/tmp/nested_release.zip" "FILE ZIP LỒNG (Zip bọc sẵn Frameworks/ - Giống Github Release 1.3.0)"

echo "=== TẤT CẢ TEST ĐỀU PASSED! ==="
