#!/bin/bash
echo "🚀 Тестируем HMAC-SHA256 TPS"

sleep 1
wrk -t4 -c50 -d10s -s post_HMAC_SHA-256.lua http://31.129.100.187:8081/session
