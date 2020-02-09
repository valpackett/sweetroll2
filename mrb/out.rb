lambda do |env|
  if env["h2o.remaining_delegations"] == 5
    return [401, {}, ["Where do you think you're going??"]]
  end
  if File.exist?(File.join(ENV["SR2_STATIC_GEN_OUT_DIR"] || "out/", env["PATH_INFO"], "gone"))
    # XXX: No way to serve the file still??
    return [410, {
      "link" => "<#{env['rack.url_scheme']}://#{env['SERVER_NAME']}#{env['PATH_INFO']}>; rel=\"self\""
    }, ["Gone"]]
  end
  return [399, {
    "link" => "<#{env['rack.url_scheme']}://#{env['SERVER_NAME']}#{env['PATH_INFO']}>; rel=\"self\""
  }, []]
end
