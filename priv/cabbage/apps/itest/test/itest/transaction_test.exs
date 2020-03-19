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

defmodule TransactionsTests do
  use Cabbage.Feature, async: true, file: "transactions.feature"

  require Logger

  alias Itest.Account

  alias Itest.Client
  alias Itest.Transactions.Currency

  # needs to be an even number, because we split the accounts in half, the first half sends ETH
  # to the other half
  @num_accounts 4
  setup do
    # {alices, bobs} =
    #   @num_accounts
    #   |> Account.take_accounts()
    #   |> Enum.split(div(@num_accounts, 2))
    # IO.inspect alices
    # IO.inspect bobs
    {alices, bobs} =
      {[
         {"0x17a4bcc20af9a0aea734f6089a47d2d3ff74e035",
          "3D0AF011CDC88AF22091604C7D06564F8F3C93B0BEA7E51AB1FF9D974D43EC33"},
         {"0x0e51dac08006992214116cd1cd3a5f3a98485cfc",
          "6A5E27AA79D95CFDF89037AC3CC7769EE02B542873CF0F05A98ACAA8C0535C75"}
       ],
       [
         {"0x3d58056c73c8cbb09bc1ed427943b609b40915a2",
          "DE1A38127A2005BD5B91A34FCDA930BF12CD08A47B5BA19B95EB21C557E5EEE6"},
         {"0x8c872716d3aafcd0c4510fb07c5d7ed9500b994d",
          "1EB35CC3313487704F0A6069760BAD5B914C2F2217F8EB4CDCBCA42A2B3782E8"}
       ]}

    %{alices: alices, bobs: bobs}
  end

  defwhen ~r/^they deposit "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          %{alices: alices} = state do
    state =
      alices
      |> Enum.with_index()
      |> Task.async_stream(
        fn {{alice_account, _alice_pkey}, index} ->
          initial_balance = Itest.Poller.eth_get_balance(alice_account)

          key = String.to_atom("alice_initial_balance_#{index}")
          data = [{key, initial_balance}]

          {:ok, receipt_hash} =
            amount
            |> Currency.to_wei()
            |> Client.deposit(alice_account, Itest.PlasmaFramework.vault(Currency.ether()))

          gas_used = Client.get_gas_used(receipt_hash)
          key = String.to_atom("alice_gas_used_#{index}")
          data = [{key, gas_used} | data]

          balance_after_deposit = Itest.Poller.eth_get_balance(alice_account)

          key = String.to_atom("alice_ethereum_balance_#{index}")

          data = [{key, balance_after_deposit} | data]
          Map.put(state, String.to_atom("alice_data_#{index}"), data)
        end,
        timeout: 60_000,
        on_timeout: :kill_task,
        max_concurrency: @num_accounts
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.reduce(%{}, fn state, acc -> Map.merge(state, acc) end)

    {:ok, state}
  end

  defthen ~r/^they should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alices: alices} = state do
    {:ok, response} =
      WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

    watcher_security_critical_config =
      WatcherSecurityCriticalConfiguration.to_struct(Jason.decode!(response.body)["data"])

    finality_margin_blocks = watcher_security_critical_config.deposit_finality_margin

    alices
    |> Enum.with_index()
    |> Task.async_stream(
      fn {{alice_account, alice_pkey}, index} ->
        to_milliseconds = 1000
        geth_block_every = 1

        finality_margin_blocks
        |> Kernel.*(geth_block_every)
        |> Kernel.*(to_milliseconds)
        |> Kernel.round()
        |> Process.sleep()

        expected_amount = Currency.to_wei(amount)

        balance = Client.get_balance(alice_account, expected_amount)

        balance = balance["amount"]
        assert_equal(expected_amount, balance, "For #{alice_account}")
      end,
      timeout: 60_000,
      on_timeout: :kill_task,
      max_concurrency: @num_accounts
    )
    |> Enum.map(fn {:ok, result} -> result end)

    {:ok, state}
  end

  defwhen ~r/^they send others "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alices: alices, bobs: bobs} = state do
    alices
    |> Enum.zip(bobs)
    |> Enum.with_index()
    |> Task.async_stream(
      fn {{{alice_account, alice_pkey}, {bob_account, _bob_pkey}}, _index} ->
        {:ok, [sign_hash, typed_data, _txbytes]} =
          Client.create_transaction(
            Currency.to_wei(amount),
            alice_account,
            bob_account
          )

        # Alice needs to sign 2 inputs of 1 Eth, 1 for Bob and 1 for the fees
        _ = Client.submit_transaction(typed_data, sign_hash, [alice_pkey, alice_pkey])
      end,
      timeout: 60_000,
      on_timeout: :kill_task,
      max_concurrency: @num_accounts
    )
    |> Enum.map(fn {:ok, result} -> result end)

    {:ok, state}
  end

  defthen ~r/^they should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alices: alices} = state do
    alices
    |> Enum.with_index()
    |> Task.async_stream(
      fn {{alice_account, _}, index} ->
        expecting_amount = Currency.to_wei(amount)

        balance = Client.get_balance(alice_account, expecting_amount)
        balance = balance["amount"]

        assert_equal(Currency.to_wei(amount), balance, "For #{alice_account} #{index}.")
      end,
      timeout: 60_000,
      on_timeout: :kill_task,
      max_concurrency: @num_accounts
    )
    |> Enum.map(fn {:ok, result} -> result end)

    {:ok, state}
  end

  defthen ~r/^others should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{bobs: bobs} = state do
    bobs
    |> Enum.with_index()
    |> Task.async_stream(
      fn {{bob_account, _}, index} ->
        balance = Client.get_balance(bob_account)["amount"]

        assert_equal(Currency.to_wei(amount), balance, "For #{bob_account} #{index}.")
      end,
      timeout: 60_000,
      on_timeout: :kill_task,
      max_concurrency: @num_accounts
    )
    |> Enum.map(fn {:ok, result} -> result end)

    {:ok, state}
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end
