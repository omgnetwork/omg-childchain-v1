import Config

# This `releases.exs` config file gets evaluated at RUNTIME, unlike other config files that are
# evaluated at compile-time.
#
# See https://hexdocs.pm/mix/1.9.0/Mix.Tasks.Release.html#module-runtime-configuration

config :omg_child_chain,
  block_submit_stall_threshold_blocks: String.to_integer(System.get_env("BLOCK_SUBMIT_STALL_THRESHOLD_BLOCKS") || "4"),
  block_submit_every_nth: String.to_integer(System.get_env("BLOCK_SUBMIT_EVERY_NTH", "1")),
  block_has_at_least_txs_in_block: String.to_integer(System.get_env("BLOCK_HAS_AT_LEAST_TXS_IN_BLOCK", "1")),
  force_block_submission_after_ms: String.to_integer(System.get_env("FORCE_BLOCK_SUBMISSION_AFTER_MS", "70000"))

config :gas, Gas.Integration.Pulse, api_key: System.get_env("PULSE_API_KEY")
