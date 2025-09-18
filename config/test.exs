import Config

config :logger, level: :warning

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :teslamate, TeslaMateWeb.Endpoint, server: false
config :teslamate, TeslaMate.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :phoenix, :plug_init_mode, :runtime

# Disable authentication for tests
config :teslamate, :authentication_disabled, true

# Configure test environment variables
System.put_env("HTTP_BINDING_ADDRESS", "127.0.0.1")
System.put_env("DISABLE_TLS", "true")
