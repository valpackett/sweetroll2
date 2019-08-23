defmodule Sweetroll2.Application do
  # https://hexdocs.pm/elixir/Application.html
  # https://hexdocs.pm/elixir/Supervisor.html
  @moduledoc false

  alias Supervisor.Spec
  use Application

  def start(_type, _args) do
    :ok = Logger.add_translator({Timber.Exceptions.Translator, :translate})

    server_opts =
      [protocol_options: [idle_timeout: 10 * 60000]] ++
        case {System.get_env("SR2_SERVER_SOCKET"), System.get_env("SR2_SERVER_PORT")} do
          {nil, nil} -> [port: 6969]
          {nil, port} -> [port: String.to_integer(port)]
          {sock, _} -> [ip: {:local, sock}, port: 0]
        end

    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: Sweetroll2.Serve, options: server_opts),
      Spec.worker(Sweetroll2.Application.Scheduler, []),
      Supervisor.child_spec(
        {ConCache,
         [name: :asset_rev, ttl_check_interval: :timer.minutes(1), global_ttl: :timer.minutes(60)]},
        id: :cache_asset
      ),
      Supervisor.child_spec(
        {ConCache,
         [
           name: :parsed_tpl,
           ttl_check_interval: :timer.minutes(30),
           global_ttl: :timer.hours(12)
         ]},
        id: :cache_tpl
      ),
      Supervisor.child_spec(
        {ConCache,
         [
           name: :misc,
           ttl_check_interval: :timer.minutes(30),
           global_ttl: :timer.hours(12)
         ]},
        id: :cache_misc
      ),
      {Sweetroll2.Job.Compress.AssetWatcher, dirs: ["priv/static"]},
      Sweetroll2.Events
    ]

    opts = [strategy: :one_for_one, name: Sweetroll2.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def setup!(nodes \\ [node()]) do
    if path = Application.get_env(:mnesia, :dir) do
      :ok = File.mkdir_p!(path)
    end

    Memento.stop()
    Memento.Schema.create(nodes)
    Memento.start()
    Que.Persistence.Mnesia.setup!()
    Memento.Table.create!(Sweetroll2.Post, disc_copies: nodes)
    Memento.Table.create!(Sweetroll2.Auth.Session, disc_copies: nodes)
    Memento.Table.create!(Sweetroll2.Auth.TempCode, disc_copies: nodes)
    Memento.Table.create!(Sweetroll2.Auth.AccessToken, disc_copies: nodes)
  end

  def bootstrap! do
    Memento.transaction!(fn ->
      Memento.Query.write(%Sweetroll2.Post{
        url: "/",
        type: "x-custom-page",
        props: %{
          "name" => "Home",
          "site-name" => "a new sweetroll2 website",
          "content" => [%{"html" => ~S[<!DOCTYPE html>
<html lang="en">
	{% head %}
	<body>
		{% header %}
		<main>
			<div class="block-thingy h-card">
				<data class="u-url u-uid" value="{{ canonical_home_url }}"></data>
				<h1 class="entry-txt">Hello</h1>
				<p class="entry-txt">
					Congratulations, <span class="p-name">new Sweetroll2 user</span>! Please customize this page by logging in and clicking Edit.
				</p>
			</div>
			<div class="h-feed">
				<h1 class="entry-txt"><a href="/posts" class="u-url">Current posts</a></h1>
				{% feedpreview /posts %}
				<div class="entry-txt"><a href="/posts" class="u-url">read more</a></div>
			</div>
		</main>
		{% footer %}
	</body>
</html>]}]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/posts",
        type: "x-dynamic-feed",
        props: %{
          "name" => "Posts",
          "feed-settings" => [
            %{"order-in-nav" => 0, "show-in-nav" => true, "show-in-post" => true}
          ],
          "filter" => [
            %{"category" => ["_notes"]},
            %{"category" => ["_articles"]},
            %{"category" => ["_reposts"]},
            %{"index-display" => ["show"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]},
            %{"index-display" => ["hide"]}
          ]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/notes",
        type: "x-dynamic-feed",
        props: %{
          "name" => "Notes",
          "feed-settings" => [
            %{"show-in-nav" => false, "show-in-post" => true}
          ],
          "filter" => [
            %{"category" => ["_notes"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]}
          ]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/replies",
        type: "x-dynamic-feed",
        props: %{
          "name" => "Replies",
          "feed-settings" => [
            %{"show-in-nav" => false, "show-in-post" => true}
          ],
          "filter" => [
            %{"category" => ["_replies"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]}
          ]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/likes",
        type: "x-dynamic-feed",
        props: %{
          "name" => "Likes",
          "feed-settings" => [
            %{"show-in-nav" => false, "show-in-post" => true}
          ],
          "filter" => [
            %{"category" => ["_likes"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]}
          ]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/rsvp",
        type: "x-dynamic-feed",
        props: %{
          "name" => "RSVPs",
          "feed-settings" => [
            %{"show-in-nav" => false, "show-in-post" => true}
          ],
          "filter" => [
            %{"category" => ["_rsvp"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]}
          ]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/photos",
        type: "x-dynamic-feed",
        props: %{
          "name" => "Photos",
          "feed-settings" => [
            %{
              "order-in-nav" => 10,
              "show-in-nav" => true,
              "show-in-post" => true,
              "layout" => "gallery"
            }
          ],
          "filter" => [
            %{"category" => ["_photos"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]}
          ]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/kb",
        type: "x-dynamic-feed",
        props: %{
          "name" => "KB",
          "feed-settings" => [
            %{
              "order-in-nav" => 20,
              "show-in-nav" => true,
              "show-in-post" => true,
              "layout" => "knowledgebase",
              "limit" => 0,
              "sort" => "name"
            }
          ],
          "filter" => [
            %{"category" => ["_kb"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]}
          ]
        }
      })

      Memento.Query.write(%Sweetroll2.Post{
        url: "/bookmarks",
        type: "x-dynamic-feed",
        props: %{
          "name" => "Bookmarks",
          "feed-settings" => [
            %{"order-in-nav" => 30, "show-in-nav" => true, "show-in-post" => true}
          ],
          "filter" => [
            %{"category" => ["_bookmarks"]}
          ],
          "unfilter" => [
            %{"client-id" => ["https://micropub.rocks/"]}
          ]
        }
      })

      now = DateTime.utc_now()

      Memento.Query.write(%Sweetroll2.Post{
        url: "/notes/#{to_string(now) |> String.replace(" ", "-")}",
        type: "entry",
        published: now,
        props: %{
          "category" => ["_notes"],
          "content" => [
            %{
              "markdown" =>
                "Welcome to *Sweetroll2*! This is an example note. You can delete it and write your own instead :)"
            }
          ]
        }
      })
    end)
  end

  defmodule Scheduler do
    use Quantum.Scheduler, otp_app: :sweetroll2
  end
end
