import Config

config :logger,
  backends: [:console, Sentry.LoggerBackend]

config :omg,
  ethereum_events_check_interval_ms: 500,
  coordinator_eth_height_check_interval_ms: 1_000

config :omg_child_chain,
  block_queue_eth_height_check_interval_ms: 1_000

config :omg_child_chain_rpc, environment: :dev
config :phoenix, :stacktrace_depth, 20

config :omg_child_chain_rpc, OMG.ChildChainRPC.Tracer,
  disabled?: true,
  env: "development"

config :omg_db,
  path: Path.join([System.get_env("HOME"), ".omg/data"])

config :ethereumex,
  http_options: [recv_timeout: 60_000]

config :omg_eth,
  min_exit_period_seconds: 10 * 60,
  ethereum_block_time_seconds: 1

config :phoenix, :stacktrace_depth, 20

config :omg_status, OMG.Status.Metric.Tracer,
  env: "development",
  disabled?: true
