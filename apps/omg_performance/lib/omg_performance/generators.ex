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

defmodule OMG.Performance.Generators do
  @moduledoc """
  Provides helper functions to generate bundles of various useful entities for performance tests
  """
  require OMG.Utxo

  alias Support.DevHelper

  @generate_user_timeout 600_000

  @doc """
  Creates addresses with private keys and funds them with given `initial_funds_wei` on geth.

  Options:
    - :faucet - the address to send the test ETH from, assumed to be unlocked and have the necessary funds
    - :initial_funds_wei - the amount of test ETH that will be granted to every generated user
  """
  @spec generate_users(non_neg_integer, [Keyword.t()]) :: [OMG.TestHelper.entity()]
  def generate_users(size, opts \\ []) do
    1..size
    |> Task.async_stream(fn _ -> generate_user(opts) end, timeout: @generate_user_timeout)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp generate_user(opts) do
    user = OMG.TestHelper.generate_entity()
    {:ok, _user} = DevHelper.import_unlock_fund(user, opts)
    user
  end
end
