lambda do |env|
  if env["PATH_INFO"].end_with?("/") && env["PATH_INFO"] != "/"
    loc = env["PATH_INFO"]
    while loc.end_with?("/") && loc != "/"
      loc = loc.chomp("/")
    end
    if env["QUERY_STRING"].length > 0
      loc += "?#{env["QUERY_STRING"]}"
    end
    return [301, { "location" => loc }, []]
  end
  if (env["HTTP_COOKIE"].nil? || !env["HTTP_COOKIE"].include?("wheeeee=C")) &&
      File.exist?(File.join(ENV["SR2_STATIC_GEN_OUT_DIR"] || "out/", env["PATH_INFO"], "index.html"))
    return [307, { "x-reproxy-url" => "/__out__" + env["PATH_INFO"] }, []]
  end
  return [399, {}, []]
end
