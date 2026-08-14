# Sessions are 30 days sliding (PRD §12). The cookie carries only the session
# token; the authoritative record is the Session row, so a device can be
# revoked server-side.
Rails.application.config.session_store :cookie_store,
  key: "_notbuk_session",
  same_site: :lax,
  expire_after: 30.days
