#!/bin/bash
echo "🚀 Тестируем AES-GCM-SIV TPS"
sleep 1
wrk -t4 -c50 -d10s -s post_AES-GCM-SIV_aes.lua http://31.129.100.187:8083/session
