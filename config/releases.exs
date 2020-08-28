import Config

# This `releases.exs` config file gets evaluated at RUNTIME, unlike other config files that are
# evaluated at compile-time.
#
# See https://hexdocs.pm/mix/1.9.0/Mix.Tasks.Release.html#module-runtime-configuration

config :omg_child_chain,
  block_submit_stall_threshold_blocks: String.to_integer(System.get_env("BLOCK_SUBMIT_STALL_THRESHOLD_BLOCKS") || "4")
