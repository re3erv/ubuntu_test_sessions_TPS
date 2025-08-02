#!/bin/bash

### HMAC-BLAKE3_test.sh ###

echo "\n🚀 Тестируем HMAC-BLAKE3 TPS"
wrk -t4 -c50 -d10s -s post_HMAC_HMAC-BLAKE3.lua http://31.129.100.187:8084/session
