#!/bin/bash
set -euo pipefail

# Profile Generation Test
echo "=========================================================="
echo "🐚 Profile Generation Test"
echo "=========================================================="

echo "1. Running generation..."
if ! make gen-profiles > /dev/null 2>&1; then
    echo "❌ make gen-profiles failed"
    exit 1
fi

echo -e "\n2. Verifying files..."
for f in profile_galera profile_repli; do
    if [ -f "$f" ]; then
        echo "✅ File exists: $f"
        if grep -q "alias mariadb-" "$f"; then
            echo "✅ $f contains database aliases"
        else
            echo "❌ $f does NOT contain expected database aliases"
            exit 1
        fi
        if grep -q "alias ssh-" "$f"; then
            echo "✅ $f contains SSH aliases"
        else
            echo "❌ $f does NOT contain expected SSH aliases"
            exit 1
        fi
    else
        echo "❌ Missing file: $f"
        exit 1
    fi
done

echo -e "\n=========================================================="
echo "🎉 Profile Generation Test Passed!"
echo "=========================================================="
