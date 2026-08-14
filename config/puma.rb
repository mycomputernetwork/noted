threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

# Single-process. SQLite plus a handful of users does not need clustering, and
# a single process keeps the Solid Queue supervisor simple under launchd.
workers 0

plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")
