# Sweetroll2 (is abandoned, sorry)

A powerful micro/blogging engine with [IndieWeb] features.

- monolithic BEAM app written in [Elixir] with no external database (everything is stored in Mnesia)
- your site is dynamic and static at the same time
  - it's not a traditional "static site generator", it's very much a long-running server
  - but all pages are saved to static HTML files for performance (served from a frontend server like [h2o])
- uniform data model: every page is a [microformats2] style object
  - special object types are used for stuff like feeds (for dynamic feeds, `children` are the result of a query)
  - and they create more virtual pages (e.g. dynamic feeds are paginated: `/notes` → `/notes/page1`, `/notes/page2`…)
- asset management: automatic compression and cache busting
- local password authentication, [IndieAuth] app authorization
- [Micropub] is the primary way of working with pages
  - [micro-panel] is integrated as the post editing interface
- [Webmentions] are supported for distributed conversations across websites
  - [Salmentions] are sent as a natural consequence of the architecture (received mention → update event → mentions are sent)
- [WebSub] notifications are sent for quick updates in readers

[IndieWeb]: https://indieweb.org/
[Elixir]: https://elixir-lang.org/
[h2o]: https://h2o.examp1e.net/
[microformats2]: http://microformats.org/wiki/microformats2
[IndieAuth]: https://indieweb.org/IndieAuth
[Micropub]: https://indieweb.org/micropub
[micro-panel]: https://github.com/myfreeweb/micro-panel
[Webmentions]: https://indieweb.org/webmention
[Salmentions]: https://indieweb.org/Salmention
[WebSub]: https://indieweb.org/WebSub

## Usage

Mix tasks:

- `sweetroll2.setup` creates the database
- `sweetroll2.bootstrap` adds initial posts
- `sweetroll2.drop` deletes the database

Environment variables:

- `MIX_ENV`: in `prod`, logging will be in JSON (ready for [shipping somewhere with something](https://docs.timber.io/setup/log-forwarders/fluent-bit)), scheduled background tasks will be active, the plug debug middleware won't be active, etc.
- `SR2_SERVER_SOCKET` or `SR2_SERVER_PORT`: where to listen for connections (default is port 6969)
- `SR2_PASSWORD_HASH`: Argon2 hash of the admin password (REQUIRED, e.g. `$argon2id$v=19$m=…`)
- `SR2_CANONICAL_HOME_URL`: scheme and hostname (NO SLASH) of the website (REQUIRED, e.g. `https://example.com`)
- `SR2_WEBSUB_HUB`: URL of the WebSub hub to use (default `https://pubsubhubbub.superfeedr.com/`) (make sure to also modify in h2o settings for static files!!)
- `SR2_STATIC_GEN_OUT_DIR`: where to write static HTML (default `out`; also the h2o scripts use it!)

## License

This is free and unencumbered software released into the public domain.  
For more information, please refer to the `UNLICENSE` file or [unlicense.org](http://unlicense.org).

(Note: different licenses apply to dependencies.)
