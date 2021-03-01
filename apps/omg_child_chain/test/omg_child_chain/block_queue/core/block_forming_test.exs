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

defmodule OMG.ChildChain.BlockQueue.Core.BlockFormingTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias OMG.ChildChain.BlockQueue.Core
  alias OMG.ChildChain.BlockQueue.Core.BlockForming
  @child_block_interval 1000

  setup do
    {:ok, state} =
      Core.new(
        mined_child_block_num: 0,
        known_hashes: [],
        top_mined_hash: <<0::256>>,
        parent_height: 0,
        child_block_interval: @child_block_interval
      )

    {:ok, %{state: state}}
  end

  test "that we form a block when we meet the transaction number threshold", %{state: state} do
    assert state
           |> Map.put(:block_has_at_least_txs_in_block, 5)
           |> Map.put(:parent_height, 5000)
           |> Map.put(:last_enqueued_block_at_height, 4999)
           |> BlockForming.should_form_block?(6)
  end

  test "that we don't form a block when we have not meet the transaction number threshold", %{state: state} do
    assert {false, _} =
             state
             |> Map.put(:block_has_at_least_txs_in_block, 5)
             |> Map.put(:parent_height, 5000)
             |> Map.put(:last_enqueued_block_at_height, 4999)
             |> BlockForming.should_form_block?(4)
  end

  test "that we form a block when we're past the force_block_submission_countdown and there's not enough transactions",
       %{state: state} do
    new_state =
      state
      |> Map.put(:block_has_at_least_txs_in_block, 5)
      |> Map.put(:parent_height, 5000)
      |> Map.put(:last_enqueued_block_at_height, 4999)

    {false, utc_then} = BlockForming.should_form_block?(new_state, 4)

    force_block_submission_after_ms = 10
    Process.sleep(force_block_submission_after_ms + 1)

    assert true =
             new_state
             |> Map.put(:force_block_submission_countdown, utc_then)
             |> Map.put(:force_block_submission_after_ms, force_block_submission_after_ms)
             |> BlockForming.should_form_block?(4)
  end
end
