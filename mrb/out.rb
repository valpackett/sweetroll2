lambda do |env|
  if env["h2o.remaining_delegations"] == 5
    return [401, {}, ["Where do you think you're going??"]]
  end
  return [399, {
    "link" => "<#{env['rack.url_scheme']}://#{env['SERVER_NAME']}#{env['PATH_INFO']}>; rel=\"self\""
  }, []]
end
