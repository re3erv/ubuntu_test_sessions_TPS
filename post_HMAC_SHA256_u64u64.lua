local base64_token = ""

wrk.method = "POST"
wrk.body   = '{"user_id":1234567890123456789,"expires":4102444800,"role":2}'
wrk.headers["Content-Type"] = "application/json"

function request()
    if base64_token == "" then
        return wrk.format(nil, "/session", nil, wrk.body)
    else
        return wrk.format("POST", "/session/check", {["Content-Type"]="text/plain"}, base64_token)
    end
end

function response(status, headers, body)
    if status == 200 and base64_token == "" then
        base64_token = body
        print("Получен токен: "..base64_token)
    end
end
