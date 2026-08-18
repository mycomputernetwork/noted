threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Production is reached only through newt (Pangolin's local client), which
# proxies over loopback. Binding to 127.0.0.1 means nothing on the tailnet or
# LAN can hit the app directly, bypassing Pangolin's auth. Dev stays on all
# interfaces (Puma's default) since the Android client reaches it over the
# LAN from a physical device (clients/README.md); `bind` and `port` both set
# the listener, so only one may be used.
if ENV["RAILS_ENV"] == "production"
  bind "tcp://127.0.0.1:#{ENV.fetch("PORT", 3000)}"
  bind "tcp://[::1]:#{ENV.fetch("PORT", 3000)}"
else
  port ENV.fetch("PORT", 3000)
end

# Single-process. SQLite plus a handful of users does not need clustering, and
# a single process keeps the Solid Queue supervisor simple under launchd.
workers 0

plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")
