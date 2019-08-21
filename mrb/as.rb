lambda do |env|
  headers = {}
  if env["QUERY_STRING"].include?("vsn=")
    headers["cache-control"] = "public, max-age=31536000, immutable"
  end
  return [399, headers, []]
end
