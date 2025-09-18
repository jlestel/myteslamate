defmodule TeslaMateWeb.Router do
  use TeslaMateWeb, :router

  alias TeslaMate.Settings

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :require_auth
    plug :force_https_redirect

    plug Cldr.Plug.AcceptLanguage,
      cldr_backend: TeslaMateWeb.Cldr,
      no_match_log_level: :debug

    plug Cldr.Plug.PutLocale,
      apps: [:cldr, :gettext],
      from: [:query, :session, :accept_language],
      gettext: TeslaMateWeb.Gettext,
      cldr: TeslaMateWeb.Cldr

    plug TeslaMateWeb.Plugs.PutSession

    plug :put_root_layout, {TeslaMateWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_settings
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TeslaMateWeb do
    pipe_through :browser

    get "/", CarController, :index
    get "/drive/:id/gpx", DriveController, :gpx

    live_session :default do
      live "/sign_in", SignInLive.Index
      live "/settings", SettingsLive.Index
      live "/geo-fences", GeoFenceLive.Index
      live "/geo-fences/new", GeoFenceLive.Form
      live "/geo-fences/:id/edit", GeoFenceLive.Form
      live "/charge-cost/:id", ChargeLive.Cost
      live "/import", ImportLive.Index
    end
  end

  scope "/api", TeslaMateWeb do
    pipe_through :api

    put "/car/:id/logging/resume", CarController, :resume_logging
    put "/car/:id/logging/suspend", CarController, :suspend_logging
  end

  def force_https_redirect(conn, _opts) do
    # Check if HTTPS redirection is enabled
    force_https = System.get_env("FORCE_HTTPS", "true") == "true"
    external_binding = System.get_env("HTTP_BINDING_ADDRESS", "") in ["", "0.0.0.0", "::1"]
    tls_enabled = System.get_env("DISABLE_TLS", "false") != "true"

    should_redirect = (tls_enabled or external_binding) and (force_https or external_binding) and conn.scheme == :http

    unless should_redirect do
      require Logger
      Logger.debug("""
      force_https_redirect: Not redirecting.
      tls_enabled: #{inspect(tls_enabled)}
      force_https: #{inspect(force_https)}
      external_binding: #{inspect(external_binding)}
      conn.scheme: #{inspect(conn.scheme)}
      """)
    end

    if should_redirect do
      https_port = System.get_env("HTTPS_PORT", "4001")
      port_suffix = if https_port == "443", do: "", else: ":#{https_port}"

      conn
      |> Phoenix.Controller.redirect(external: "https://#{conn.host}#{port_suffix}#{conn.request_path}")
      |> halt()
    else
      conn
    end
  end

  def require_auth(conn, _opts) do
    # Disable authentication in test environment or if explicitly disabled
    if Mix.env() == :test or Application.get_env(:teslamate, :authentication_disabled, false) do
      conn
    else
      # Validate BASIC_AUTH_PASS before applying auth
      basic_auth_user = System.get_env("BASIC_AUTH_USER") || "myteslamate"
      basic_auth_pass = System.get_env("BASIC_AUTH_PASS") || "mypassword"

      validate_basic_auth_pass!(basic_auth_pass)

      Plug.BasicAuth.basic_auth(conn, username: basic_auth_user, password: basic_auth_pass)
    end
  end

  defp validate_basic_auth_pass!(basic_auth_pass) do
    if is_nil(basic_auth_pass) or String.trim(basic_auth_pass) == "" do
      raise "BASIC_AUTH_PASS cannot be empty"
    end

    # Verify that the password is at least 8 characters long and contains both letters and numbers
    valid_length = String.length(basic_auth_pass) >= 8
    has_letter = Regex.match?(~r/[A-Za-z]/, basic_auth_pass)
    has_number = Regex.match?(~r/\d/, basic_auth_pass)

    unless valid_length and has_letter and has_number do
      raise "BASIC_AUTH_PASS must be at least 8 characters and contain both letters and numbers"
    end
  end

  def fetch_settings(conn, _opts) do
    settings = Settings.get_global_settings!()

    conn
    |> assign(:settings, settings)
    |> put_session(:settings, settings)
  end
end
