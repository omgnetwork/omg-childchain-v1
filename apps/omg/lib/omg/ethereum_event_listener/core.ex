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

defmodule OMG.EthereumEventListener.Core do
  @moduledoc """
  Logic module for the `OMG.EthereumEventListener`

  Responsible for:
    - deciding what ranges of Ethereum events should be fetched from the Ethereum node
    - deciding the right size of event batches to read (too little means many RPC requests, too big can timeout)
    - deciding what to check in into the `OMG.RootChainCoordinator`
    - deciding what to put into the `OMG.DB` in terms of Ethereum height till which the events are already processed

  Leverages a rudimentary in-memory cache for events, to be able to ask for right-sized batches of events
  """
  alias OMG.RootChainCoordinator.SyncGuide

  use Spandex.Decorators

  # synced_height is what's being exchanged with `RootChainCoordinator`. 
  # The point in root chain until where it processed
  defstruct synced_height_update_key: nil,
            service_name: nil,
            synced_height: 0,
            ethereum_events_check_interval_ms: nil,
            request_max_size: 1000

  @type event :: %{eth_height: non_neg_integer()}

  @type t() :: %__MODULE__{
          synced_height_update_key: atom(),
          service_name: atom(),
          synced_height: integer(),
          ethereum_events_check_interval_ms: non_neg_integer(),
          request_max_size: pos_integer()
        }

  @doc """
  Initializes the listener logic based on its configuration and the last persisted Ethereum height, till which events
  were processed
  """
  @spec init(atom(), atom(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: {t(), non_neg_integer()}

  def init(
        update_key,
        service_name,
        last_synced_ethereum_height,
        ethereum_events_check_interval_ms,
        request_max_size \\ 1000
      ) do
    initial_state = %__MODULE__{
      synced_height_update_key: update_key,
      synced_height: last_synced_ethereum_height,
      service_name: service_name,
      request_max_size: request_max_size,
      ethereum_events_check_interval_ms: ethereum_events_check_interval_ms
    }

    {initial_state, last_synced_ethereum_height}
  end

  @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events_range_for_download/2")
  @spec get_events_range_for_download(t(), SyncGuide.t()) ::
          {:dont_fetch_events, t()} | {:get_events, {non_neg_integer, non_neg_integer}, t()}
  def get_events_range_for_download(state, sync_guide) do
    case sync_guide.sync_height <= state.synced_height do
      true ->
        {:dont_fetch_events, state}

      _ ->
        # grab as much as allowed, but not higher than current root_chain_height and at least as much as needed to sync
        # both root_chain_height and sync_height are assumed to have any required finality margins applied by caller
        root_chain_height = sync_guide.root_chain_height
        request_max_size = state.request_max_size
        # root_chain_height is ethereums current height, we can't get pass that!
        # so we find the min between root chain height and
        # the current sync hight (state.synced_height) + what the max is (default is 1000)
        next_upper_bound = max(min(root_chain_height, state.synced_height + request_max_size), sync_guide.sync_height)

        {:get_events, {state.synced_height + 1, next_upper_bound}, %{state | synced_height: next_upper_bound}}
    end
  end
end
