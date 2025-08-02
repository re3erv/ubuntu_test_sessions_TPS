#!/bin/bash
echo "🚀 Тестируем XChaCha20-Poly1305 TPS"

sleep 1
wrk -t4 -c50 -d10s -s post_XChaCha20-Poly1305.lua http://31.129.100.187:8082/session
