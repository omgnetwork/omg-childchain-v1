# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.ChildChain.Configuration do
  @moduledoc """
  Interface for accessing all Child Chain configuration
  """
  @app :omg_child_chain

  @spec metrics_collection_interval() :: no_return() | pos_integer()
  def metrics_collection_interval() do
    Application.fetch_env!(@app, :metrics_collection_interval)
  end

  @spec block_queue_eth_height_check_interval_ms() :: no_return() | pos_integer()
  def block_queue_eth_height_check_interval_ms() do
    Application.fetch_env!(@app, :block_queue_eth_height_check_interval_ms)
  end

  @spec submission_finality_margin() :: no_return() | pos_integer()
  def submission_finality_margin() do
    Application.fetch_env!(@app, :submission_finality_margin)
  end

  @spec block_submit_every_nth() :: no_return() | pos_integer()
  def block_submit_every_nth() do
    Application.fetch_env!(@app, :block_submit_every_nth)
  end

  @spec block_has_at_least_txs_in_block() :: no_return() | pos_integer()
  def block_has_at_least_txs_in_block() do
    Application.fetch_env!(@app, :block_has_at_least_txs_in_block)
  end

  @spec force_block_submission_after_ms() :: no_return() | pos_integer()
  def force_block_submission_after_ms() do
    Application.fetch_env!(@app, :force_block_submission_after_ms)
  end

  @spec block_submit_max_gas_price() :: no_return() | pos_integer()
  def block_submit_max_gas_price() do
    Application.fetch_env!(@app, :block_submit_max_gas_price)
  end

  @spec block_submit_stall_threshold_blocks() :: pos_integer() | no_return()
  def block_submit_stall_threshold_blocks() do
    Application.fetch_env!(@app, :block_submit_stall_threshold_blocks)
  end

  @doc """
  Prepares options Keyword for the FeeServer process
  """
  @spec fee_server_opts() :: no_return() | Keyword.t()
  def fee_server_opts() do
    fee_server_opts = [
      fee_adapter_check_interval_ms: Application.fetch_env!(@app, :fee_adapter_check_interval_ms),
      fee_buffer_duration_ms: Application.fetch_env!(@app, :fee_buffer_duration_ms)
    ]

    {adapter, opts: adapter_opts} = fee_adapter_opts()

    Keyword.merge(fee_server_opts, fee_adapter: adapter, fee_adapter_opts: adapter_opts)
  end

  @spec fee_adapter_opts() :: no_return() | tuple()
  defp fee_adapter_opts() do
    Application.fetch_env!(@app, :fee_adapter)
  end
end
