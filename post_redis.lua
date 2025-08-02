wrk.method = "POST"
wrk.body = '{"user_id":1,"expires":12345678,"role":2}'
wrk.headers["Content-Type"] = "application/json"

response = function(status, headers, body)
  return status >= 200 and status < 300
end
