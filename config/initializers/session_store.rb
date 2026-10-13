Rails.application.config.session_store :cookie_store,
  key: "_online_poker_session",
  same_site: :lax,
  secure: Rails.env.production?
