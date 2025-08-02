#!/bin/bash
echo "🚀 Тестируем Redis TPS"

sleep 1
wrk -t4 -c50 -d10s -s post_redis.lua http://31.129.100.187:8082/session
