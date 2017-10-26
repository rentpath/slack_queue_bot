use Mix.Config

config :queue_bot, :redis_client,
  use_redis: true

config :exredis,
  host: "redis",
  port: 6379,
  db: 8,
  reconnect: 100,
  max_queue: :infinity
