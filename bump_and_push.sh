#!/bin/bash
# bump_and_push.sh
# Tự động tăng build number trong pubspec.yaml và push lên cả 2 remote (GitLab & GitHub)

set -e

# Di chuyển vào thư mục chứa script
cd "$(dirname "$0")"

# 1. Đọc dòng chứa version hiện tại từ pubspec.yaml
VERSION_LINE=$(grep '^version:' pubspec.yaml)
echo "Dòng phiên bản hiện tại: $VERSION_LINE"

# Trích xuất phần version và build number (Ví dụ: 2.4.0+40 -> 2.4.0 và 40)
VERSION_PART=$(echo "$VERSION_LINE" | awk '{print $2}' | cut -d+ -f1)
CURRENT_BUILD=$(echo "$VERSION_LINE" | awk '{print $2}' | cut -d+ -f2)

# Xác định số build mới: nếu truyền tham số thì lấy tham số, không thì tự tăng +1
if [ -n "$1" ]; then
    NEW_BUILD=$1
    echo "🎯 Sử dụng số build chỉ định: $NEW_BUILD"
else
    NEW_BUILD=$((CURRENT_BUILD + 1))
    echo "🔄 Tự động tăng số build: $CURRENT_BUILD -> $NEW_BUILD"
fi

NEW_VERSION="$VERSION_PART+$NEW_BUILD"
echo "➡️ Phiên bản mới sẽ cập nhật: $NEW_VERSION"

# 2. Ghi đè phiên bản mới vào file pubspec.yaml (hỗ trợ cả macOS và Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
else
    sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
fi

# 3. Kiểm tra mã nguồn trước khi push
echo "🔍 Đang chạy kiểm tra mã nguồn..."
if command -v flutter >/dev/null 2>&1; then
    flutter analyze
else
    echo "ℹ️ Flutter binary không có sẵn trên môi trường terminal này, bỏ qua static check."
fi

# 4. Thực hiện Commit và đẩy code lên hai Remote
if git diff --quiet pubspec.yaml; then
    echo "ℹ️ Phiên bản trong pubspec.yaml đã là $NEW_VERSION, không có thay đổi mới để commit."
else
    echo "💾 Đang tạo commit..."
    git add pubspec.yaml
    git commit -m "bump(ios): nâng số build lên $NEW_BUILD để tránh trùng lặp TestFlight" \
               -m "Authored-By: 360org <support@360.org.vn>"
fi

echo "🚀 Đang đẩy code lên GitLab (origin)..."
git push origin release/ios-appstore

echo "🚀 Đang đẩy code lên GitHub (github)..."
git push github release/ios-appstore

echo "✅ Hoàn tất nâng cấp bản build: $NEW_VERSION"
