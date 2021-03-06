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

defmodule OMG.ChildChain.BlockQueue.CoreTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias OMG.ChildChain.BlockQueue.Core

  @child_block_interval 1000

  # responses from geth to simulate what we're getting from geth in `BlockQueue`
  @known_transaction_response {:error, %{"code" => -32_000, "message" => "known transaction tx"}}
  @transaction_underpriced_response {:error, %{"code" => -32_000, "message" => "transaction underpriced"}}
  @replacement_transaction_response {:error, %{"code" => -32_000, "message" => "replacement transaction underpriced"}}
  @nonce_too_low_response {:error, %{"code" => -32_000, "message" => "nonce too low"}}
  @account_locked_response {:error, %{"code" => -32_000, "message" => "authentication needed: password or unlock"}}

  @block_hash <<0::160>>

  setup do
    {:ok, empty} =
      Core.new(
        mined_child_block_num: 0,
        known_hashes: [],
        top_mined_hash: <<0::256>>,
        parent_height: 0,
        child_block_interval: @child_block_interval
      )

    {:ok, empty_high_max_gas_price} =
      Core.new(
        mined_child_block_num: 0,
        known_hashes: [],
        top_mined_hash: <<0::size(256)>>,
        parent_height: 0,
        child_block_interval: @child_block_interval
      )

    empty_with_gas_params = %{empty | formed_child_block_num: 5000}

    {:do_form_block, empty_with_gas_params} = Core.set_ethereum_status(empty_with_gas_params, 1, 3000, 1)

    {:ok,
     %{empty: empty, empty_with_gas_params: empty_with_gas_params, empty_high_max_gas_price: empty_high_max_gas_price}}
  end

  describe "child_block_nums_to_init_with/4" do
    test "Requests correct block range on initialization" do
      assert [] == Core.child_block_nums_to_init_with(0, 0, @child_block_interval, 0)
      assert [] == Core.child_block_nums_to_init_with(0, 9, @child_block_interval, 0)
      assert [1000] == Core.child_block_nums_to_init_with(0, 1000, @child_block_interval, 0)
      assert [1000, 2000, 3000] == Core.child_block_nums_to_init_with(0, 3000, @child_block_interval, 0)
      assert [100, 200, 300, 400] == Core.child_block_nums_to_init_with(0, 400, 100, 0)
      assert [2000, 3000] == Core.child_block_nums_to_init_with(2000, 3000, @child_block_interval, 0)
    end

    test "Requests correct block range on initialization, non-zero finality threshold" do
      assert [] == Core.child_block_nums_to_init_with(0, 0, @child_block_interval, 2)
      assert [] == Core.child_block_nums_to_init_with(0, 9, @child_block_interval, 2)
      assert [1000] == Core.child_block_nums_to_init_with(0, 1000, @child_block_interval, 2)
      assert [1000, 2000, 3000] == Core.child_block_nums_to_init_with(0, 3000, @child_block_interval, 2)
      assert [2000, 3000, 4000, 5000] == Core.child_block_nums_to_init_with(4000, 5000, @child_block_interval, 2)
    end
  end

  describe "new/1" do
    test "Recovers after restart to proper mined height" do
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] =
               Core.new(
                 mined_child_block_num: 7000,
                 known_hashes: [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}],
                 top_mined_hash: "7",
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )
               |> elem(1)
               |> Core.get_blocks_to_submit()
    end

    test "Recovers after restart and talking to an un-synced geth" do
      # imagine restart after geth is nuked and hasn't caught up
      # testing protecting against a disaster scenario, where `BlockQueue` would start pushing old blocks again
      {:ok, state} =
        Core.new(
          mined_child_block_num: 6000,
          known_hashes: [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}],
          top_mined_hash: "6",
          parent_height: 10,
          child_block_interval: @child_block_interval
        )

      assert [%{hash: "7", nonce: 7}, %{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] = Core.get_blocks_to_submit(state)

      # simulate geth catching up
      assert {:dont_form_block, new_state} = Core.set_ethereum_status(state, 7, 7000, 0)
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] = Core.get_blocks_to_submit(new_state)
      # still don't want to form blocks
      assert {:dont_form_block, _new_state} = Core.set_ethereum_status(state, 8, 7000, 0)
      assert {:dont_form_block, _new_state} = Core.set_ethereum_status(state, 9, 8000, 0)
    end

    test "Recovers after restart even when only empty blocks were mined" do
      assert [%{hash: "0", nonce: 8}, %{hash: "0", nonce: 9}] =
               Core.new(
                 mined_child_block_num: 7000,
                 known_hashes: [{5000, "0"}, {6000, "0"}, {7000, "0"}, {8000, "0"}, {9000, "0"}],
                 top_mined_hash: "0",
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )
               |> elem(1)
               |> Core.get_blocks_to_submit()
    end

    test "Recovers properly for fresh world state" do
      {:ok, queue} =
        Core.new(
          mined_child_block_num: 0,
          known_hashes: [],
          top_mined_hash: <<0::size(256)>>,
          parent_height: 10,
          child_block_interval: @child_block_interval
        )

      assert [] == Core.get_blocks_to_submit(queue)
    end

    test "Won't recover if is contract is ahead of db" do
      assert {:error, :contract_ahead_of_db} ==
               Core.new(
                 mined_child_block_num: 0,
                 known_hashes: [],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )
    end

    test "Won't recover if mined hash doesn't match with hash in db" do
      assert {:error, :hashes_dont_match} ==
               Core.new(
                 mined_child_block_num: 1000,
                 known_hashes: [{1000, <<2::size(256)>>}],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )
    end

    test "Won't recover if mined block number and hash don't match with db" do
      assert {:error, :mined_blknum_not_found_in_db} ==
               Core.new(
                 mined_child_block_num: 2000,
                 known_hashes: [{1000, <<1::size(256)>>}],
                 top_mined_hash: <<2::size(256)>>,
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )
    end

    test "Won't recover if mined block number doesn't match with db" do
      assert {:error, :mined_blknum_not_found_in_db} ==
               Core.new(
                 mined_child_block_num: 2000,
                 known_hashes: [{1000, <<1::size(256)>>}],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )
    end

    test "Will recover if there are blocks in db but none in root chain" do
      assert {:ok, state} =
               Core.new(
                 mined_child_block_num: 0,
                 known_hashes: [{1000, "1"}],
                 top_mined_hash: <<0::size(256)>>,
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )

      assert [%{hash: "1", nonce: 1}] = Core.get_blocks_to_submit(state)

      assert [%{hash: "1", nonce: 1}, %{hash: "2", nonce: 2}] =
               state |> Core.enqueue_block("2", 2000, 0) |> Core.get_blocks_to_submit()
    end

    test "Recovers after restart and is able to process more blocks" do
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}, %{hash: "10", nonce: 10}] =
               Core.new(
                 mined_child_block_num: 7000,
                 known_hashes: [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}],
                 top_mined_hash: "7",
                 parent_height: 10,
                 child_block_interval: @child_block_interval
               )
               |> elem(1)
               |> Core.enqueue_block("10", 10_000, 0)
               |> Core.get_blocks_to_submit()
    end
  end

  describe "set_ethereum_status/4" do
    test "offer timer when block_has_at_least_txs_in_block is not met", %{empty: empty} do
      {:dont_form_block, %{force_block_submission_countdown: nil} = queue} = Core.set_ethereum_status(empty, 0, 0, 1)

      # there's one transaction in the block, 2 is the limit (block is not empty)
      # ethereum has progressed one block ahead, so it_is_time is true
      # wait_for_enqueue is false
      assert {:dont_form_block, %{force_block_submission_countdown: force_block_submission_countdown}} =
               queue
               |> Map.put(:block_has_at_least_txs_in_block, 2)
               |> Core.set_ethereum_status(1, 0, 1)

      refute is_nil(force_block_submission_countdown)

      # there's one transaction in the block, 2 is the limit (block is not empty)
      # ethereum has progressed one block ahead, so it_is_time is true
      # wait_for_enqueue is true
      assert {:dont_form_block, %{force_block_submission_countdown: force_block_submission_countdown}} =
               queue
               |> Map.put(:block_has_at_least_txs_in_block, 2)
               |> Map.put(:wait_for_enqueue, true)
               |> Core.set_ethereum_status(1, 0, 1)

      assert is_nil(force_block_submission_countdown)
    end

    test "form block when force_block_submission_after_ms is met", %{empty: empty} do
      {:dont_form_block, %{force_block_submission_countdown: nil} = queue} = Core.set_ethereum_status(empty, 0, 0, 1)

      # there's one transaction in the block, 2 is the limit (block is not empty)
      # ethereum has progressed one block ahead, so it_is_time is true
      # wait_for_enqueue is false
      assert {:dont_form_block, state} =
               queue
               |> Map.put(:block_has_at_least_txs_in_block, 2)
               |> Core.set_ethereum_status(1, 0, 1)

      # there's one transaction in the block, 2 is the limit (block is not empty)
      # ethereum has progressed one block ahead, so it_is_time is true
      # wait_for_enqueue is false
      force_block_submission_after_ms = 2
      Process.sleep(force_block_submission_after_ms + 1)

      assert {:do_form_block, %{force_block_submission_countdown: nil, wait_for_enqueue: true}} =
               state
               |> Map.put(:block_has_at_least_txs_in_block, 2)
               |> Map.put(:force_block_submission_after_ms, force_block_submission_after_ms)
               |> Core.set_ethereum_status(1, 0, 1)
    end

    test "Asks to form block when ethereum progresses", %{empty: empty} do
      {:dont_form_block, queue} = Core.set_ethereum_status(empty, 0, 0, 1)
      assert {:do_form_block, _} = Core.set_ethereum_status(queue, 1, 0, 1)
    end

    test "Respects the block every nth setting" do
      {:ok, empty} =
        Core.new(
          mined_child_block_num: 0,
          known_hashes: [],
          top_mined_hash: <<0::256>>,
          parent_height: 0,
          child_block_interval: @child_block_interval,
          block_submit_every_nth: 3
        )

      assert {:dont_form_block, _} = Core.set_ethereum_status(empty, 0, 0, 1)
      assert {:dont_form_block, _} = Core.set_ethereum_status(empty, 1, 0, 1)
      assert {:dont_form_block, _} = Core.set_ethereum_status(empty, 2, 0, 1)
      assert {:do_form_block, _} = Core.set_ethereum_status(empty, 3, 0, 1)
    end

    test "Produced child blocks to form aren't repeated, if none are enqueued", %{empty: empty} do
      {:do_form_block, queue} = Core.set_ethereum_status(empty, 1, 0, 1)

      assert {:dont_form_block, _} = Core.set_ethereum_status(queue, 1, 0, 1)
      assert {:dont_form_block, _} = Core.set_ethereum_status(queue, 2, 0, 1)
    end

    test "Ethereum updates and enqueues can go interleaved", %{empty: empty} do
      # no enqueue after Core.set_ethereum_status(1) so don't form block
      assert {:dont_form_block, queue} =
               empty
               |> Core.set_ethereum_status(1, 0, 1)
               |> elem(1)
               |> Core.set_ethereum_status(2, 0, 1)
               |> elem(1)
               |> Core.set_ethereum_status(3, 0, 1)

      assert {:do_form_block, queue} =
               queue
               |> Core.enqueue_block("1", 1000, 0)
               |> Core.set_ethereum_status(4, 0, 1)

      assert {:dont_form_block, queue} = Core.set_ethereum_status(queue, 5, 0, 1)

      assert {:do_form_block, _queue} =
               queue
               |> Core.enqueue_block("2", 2000, 0)
               |> Core.set_ethereum_status(6, 0, 1)
    end

    # NOTE: theoretically the back off is ver hard to get - testing if this rare occasion doesn't make the state weird
    test "Ethereum updates can back off and jump independent from enqueues", %{empty: empty} do
      # no enqueue after Core.set_ethereum_status(2) so don't form block
      assert {:dont_form_block, queue} =
               empty
               |> Core.set_ethereum_status(1, 0, 1)
               |> elem(1)
               |> Core.set_ethereum_status(2, 0, 1)
               |> elem(1)
               |> Core.set_ethereum_status(1, 0, 1)

      assert {:do_form_block, queue} =
               queue
               |> Core.enqueue_block("1", 1000, 0)
               |> Core.set_ethereum_status(1, 0, 1)

      assert {:dont_form_block, queue} =
               queue
               |> Core.enqueue_block("2", 2000, 1)
               |> Core.set_ethereum_status(1, 0, 1)

      assert {:do_form_block, _queue} = Core.set_ethereum_status(queue, 2, 0, 1)
    end

    test "Block generation is driven by last enqueued block Ethereum height and if block is empty or not", %{
      empty: empty
    } do
      assert {:dont_form_block, _} = Core.set_ethereum_status(empty, 0, 0, 1)

      assert {:dont_form_block, _} = Core.set_ethereum_status(empty, 1, 0, 0)

      assert {:do_form_block, queue} = Core.set_ethereum_status(empty, 1, 0, 1)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("1", 1000, 0)
               |> Core.set_ethereum_status(0, 0, 1)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("1", 1000, 1)
               |> Core.set_ethereum_status(1, 0, 1)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("1", 1000, 0)
               |> Core.set_ethereum_status(1, 0, 0)

      # Ethereum advanced since enqueue and block isn't empty -> order forming of next block
      assert {:do_form_block, queue} =
               queue
               |> Core.enqueue_block("1", 1000, 0)
               |> Core.set_ethereum_status(1, 0, 1)

      # no enqueue
      assert {:dont_form_block, queue} = Core.set_ethereum_status(queue, 1, 0, 1)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("2", 2000, 1)
               |> Core.set_ethereum_status(1, 0, 1)

      assert {:do_form_block, _} =
               queue
               |> Core.enqueue_block("2", 2000, 1)
               |> Core.set_ethereum_status(2, 0, 1)
    end

    test "if Ethereum progressed to no later where last enqueue happened, don't ask to form", %{empty: empty} do
      assert {:dont_form_block, _queue} =
               empty
               |> Core.set_ethereum_status(0, 0, 1)
               |> elem(1)
               |> Core.enqueue_block("1", 1000, 0)
               |> Core.enqueue_block("2", 2000, 1)
               |> Core.set_ethereum_status(1, 2000, 1)
    end
  end

  describe "get_blocks_to_submit/1" do
    test "Empty queue doesn't want to submit blocks", %{empty: empty} do
      assert [] = Core.get_blocks_to_submit(empty)
    end

    test "Empty queue doesn't want to submit blocks, even if ethereum progresses", %{empty: empty} do
      assert [] =
               empty
               |> Core.set_ethereum_status(10, 3000, 1)
               |> elem(1)
               |> Core.get_blocks_to_submit()
    end

    test "A new block is submitted after enqueuing", %{empty: empty} do
      assert [%{num: 2000}] =
               empty
               |> Core.set_ethereum_status(0, 1000, 1)
               |> elem(1)
               |> Core.enqueue_block("2", 2000, 0)
               |> Core.get_blocks_to_submit()
    end

    test "multiple blocks enqueued in a row, and all unmined will be submitted", %{empty: empty} do
      {_, queue} =
        empty
        |> Core.set_ethereum_status(0, 0, 1)
        |> elem(1)
        |> Core.enqueue_block("1", 1000, 0)
        |> Core.enqueue_block("2", 2000, 1)
        |> Core.enqueue_block("3", 3000, 2)
        |> Core.enqueue_block("4", 4000, 3)
        |> Core.enqueue_block("5", 5000, 4)
        |> Core.set_ethereum_status(3, 2000, 1)

      assert [%{num: 3000}, %{num: 4000}, %{num: 5000}] = Core.get_blocks_to_submit(queue)
    end

    test "Produced blocks submission requests have nonces in order and matching the blocks", %{empty: empty} do
      assert [%{hash: "1", num: 1000, nonce: 1}, %{hash: "2", num: 2000, nonce: 2}] =
               empty
               |> Core.set_ethereum_status(0, 0, 1)
               |> elem(1)
               |> Core.enqueue_block("1", 1000, 0)
               |> Core.enqueue_block("2", 2000, 0)
               |> Core.get_blocks_to_submit()
    end
  end

  describe "enqueue_block/4" do
    test "Block is not enqueued when number of enqueued block does not match expected block number", %{empty: empty} do
      {:error, :unexpected_block_number} = Core.enqueue_block(empty, "1", 2000, 0)
    end

    test "Block is not enqueued when number of enqueued block does not match expected block number, after recovery" do
      {:ok, state} =
        Core.new(
          mined_child_block_num: 5000,
          known_hashes: [{5000, "5"}, {6000, "6"}],
          top_mined_hash: "5",
          parent_height: 10,
          child_block_interval: @child_block_interval
        )

      # either early unknown block, early known block or most recent known block
      {:error, :unexpected_block_number} = Core.enqueue_block(state, "2", 2000, 0)
      {:error, :unexpected_block_number} = Core.enqueue_block(state, "5", 5000, 0)
      {:error, :unexpected_block_number} = Core.enqueue_block(state, "6", 6000, 0)
    end

    test "Old blocks are removed, but only after finality_threshold", %{empty: empty} do
      long_length = 1_000
      short_length = 4

      # make chains where no child blocks ever get mined to bloat the object
      long = make_chain(empty, long_length)
      long_size = size(long.blocks)

      empty_size = size(empty.blocks)
      one_block_size = size(make_chain(empty, 1).blocks) - empty_size

      # sanity check if we haven't removed blocks to early
      assert long_size - empty_size >= one_block_size * long_length

      # here we suddenly mine the child blocks and the remove should happen
      long_mined_size =
        long
        |> Core.set_ethereum_status(long_length, (long_length - short_length) * 1000, 1)
        |> elem(1)
        |> Map.get(:blocks)
        |> size()

      assert long_mined_size - empty_size < (short_length + empty.finality_threshold + 1) * one_block_size
    end

    # helper function makes a chain that have size blocks
    defp make_chain(base, size) do
      Enum.reduce(1..size, base, fn hash, state ->
        Core.enqueue_block(state, hash, hash * @child_block_interval, hash)
      end)
    end

    defp size(data) do
      Enum.count(data)
    end
  end

  describe "process_submit_result/3" do
    setup do
      [submission] =
        Core.new(
          mined_child_block_num: 0,
          known_hashes: [{1000, "1"}],
          top_mined_hash: <<0::size(256)>>,
          parent_height: 10,
          child_block_interval: @child_block_interval
        )
        |> elem(1)
        |> Core.get_blocks_to_submit()

      {:ok, submission: submission}
    end

    test "everything might be ok", %{submission: submission} do
      # no change in mined blknum
      assert {:ok, @block_hash} = Core.process_submit_result(submission, {:ok, @block_hash}, 1000)
      # arbitrary ignored change in mined blknum
      assert {:ok, @block_hash} = Core.process_submit_result(submission, {:ok, @block_hash}, 0)
      assert {:ok, @block_hash} = Core.process_submit_result(submission, {:ok, @block_hash}, 2000)
    end

    test "benign reports / warnings from geth", %{submission: submission} do
      # no change in mined blknum
      assert :ok = Core.process_submit_result(submission, @known_transaction_response, 1000)

      assert :ok = Core.process_submit_result(submission, @transaction_underpriced_response, 1000)

      assert :ok = Core.process_submit_result(submission, @replacement_transaction_response, 1000)
    end

    test "benign nonce too low error - related to our tx being mined, since the mined blknum advanced",
         %{submission: submission} do
      assert :ok = Core.process_submit_result(submission, @nonce_too_low_response, 1000)
      assert :ok = Core.process_submit_result(submission, @nonce_too_low_response, 2000)
    end

    test "real nonce too low error", %{submission: submission} do
      # the new mined child block number is not the one we submitted, so we expect an error an error log
      assert capture_log(fn ->
               assert {:error, :nonce_too_low} = Core.process_submit_result(submission, @nonce_too_low_response, 0)
             end) =~ "[error]"

      assert capture_log(fn ->
               assert {:error, :nonce_too_low} = Core.process_submit_result(submission, @nonce_too_low_response, 90)
             end) =~ "[error]"
    end

    test "other fatal errors", %{submission: submission} do
      # the new mined child block number is not the one we submitted, so we expect an error an error log
      assert capture_log(fn ->
               assert {:error, :account_locked} = Core.process_submit_result(submission, @account_locked_response, 0)
             end) =~ "[error]"
    end

    test "logs unknown server error response", %{submission: submission} do
      assert capture_log(fn ->
               assert :ok =
                        Core.process_submit_result(
                          submission,
                          {:error, %{"code" => -32_000, "message" => "foo error"}},
                          1000
                        )
             end) =~ "unknown server error: %{\"code\" => -32000, \"message\" => \"foo error\"}"

      assert capture_log(fn ->
               assert :ok =
                        Core.process_submit_result(
                          submission,
                          {:error, %{"code" => -32_070, "message" => "bar error"}},
                          2000
                        )
             end) =~ "unknown server error: %{\"code\" => -32070, \"message\" => \"bar error\"}"
    end
  end
end
