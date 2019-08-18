defmodule Sweetroll2.HttpClient do
  use Tesla

  adapter(Tesla.Adapter.Hackney,
    recv_timeout: 10_000,
    ssl_options: [
      verify: :verify_peer,
      verify_fun: &:ssl_verify_hostname.verify_fun/3,
      depth: 69,
      cacertfile: default_cert_bundle()
    ]
  )

  plug Tesla.Middleware.Timeout, timeout: 11_000
  plug Tesla.Middleware.Retry, max_retries: 3
  plug Tesla.Middleware.FollowRedirects, max_redirects: 3
  plug Tesla.Middleware.Compression, format: "gzip"
  plug Tesla.Middleware.Headers, [{"user-agent", "Sweetroll2 (Tesla/hackney)"}]

  plug Tesla.Middleware.FormUrlencoded,
    encode: &Plug.Conn.Query.encode/1,
    decode: &Plug.Conn.Query.decode/1

  defp default_cert_bundle() do
    cond do
      File.exists?("/etc/ssl/cert.pem") -> "/etc/ssl/cert.pem"
      File.exists?("/etc/pki/tls/cert.pem") -> "/etc/pki/tls/cert.pem"
      File.exists?("/usr/lib/ssl/cert.pem") -> "/usr/lib/ssl/cert.pem"
      File.exists?("/etc/ssl/certs/ca-certificates.crt") -> "/etc/ssl/certs/ca-certificates.crt"
      Code.ensure_loaded(:certifi) == {:module, :certifi} -> apply(:certifi, :cacertfile, [])
      true -> nil
    end
  end
end
