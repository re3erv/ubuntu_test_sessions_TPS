#!/bin/bash
echo "🚀 Генерируем токен AES-GCM-SIV..."
TOKEN=$(curl -s -X POST http://127.0.0.1:8091/session \
    -H "Content-Type: application/json" \
    -d '{"user_id":1234567890123456789,"expires":4102444800,"role":2}')
echo "🔐 Токен:"
echo "$TOKEN"

echo -e "\n🧪 Проверка токена через curl:"
curl -s -X POST http://127.0.0.1:8091/session/check \
    -H "Content-Type: text/plain" \
    --data "$TOKEN"
echo

echo -e "\n🚀 Запускаем wrk с токеном"
wrk -t8 -c200 -d10s -s post_AES-GCM-SIV_u64u64.lua http://127.0.0.1:8091
