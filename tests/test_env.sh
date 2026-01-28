#!/bin/bash
set -euo pipefail

# Environment File Validator
echo "=========================================================="
echo "📝 Environment File Validator"
echo "=========================================================="

if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating a default one for test..."
    echo "DB_ROOT_PASSWORD=rootpass" > .env
    echo "# REPLI_USER=repli_user" >> .env
    echo "# REPLI_PASS=replipass" >> .env
    echo "✅ Created default .env"
fi

echo "1. Checking required variables..."
REQUIRED_VARS=("DB_ROOT_PASSWORD")
for var in "${REQUIRED_VARS[@]}"; do
    if grep -v '^#' .env | grep -q "^$var="; then
        VAL=$(grep -v '^#' .env | grep "^$var=" | cut -d= -f2)
        if [ -n "$VAL" ]; then
            echo "✅ $var is defined and not empty"
        else
             echo "❌ $var is defined but EMPTY"
             exit 1
        fi
    else
        echo "❌ $var is MISSING from .env"
        exit 1
    fi
done

echo -e "\n=========================================================="
echo "🎉 Environment File Validation Passed!"
echo "=========================================================="
