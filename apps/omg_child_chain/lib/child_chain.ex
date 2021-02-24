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

defmodule OMG.ChildChain do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain server's API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """
  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.FeeServer

  alias OMG.Fees
  alias OMG.Fees.FeeFilter
  alias OMG.State
  alias OMG.State.Transaction

  @type submit_result() :: {:ok, submit_success()} | {:error, submit_error()}
  @typep submit_success() :: %{txhash: Transaction.tx_hash(), blknum: pos_integer, txindex: non_neg_integer}
  @typep submit_error() :: Transaction.Recovered.recover_tx_error() | State.exec_error() | :transaction_not_supported

  @spec submit(transaction :: binary) :: submit_result()
  def submit(transaction) do
    result =
      with {:ok, {recovered_tx, fees}} <- recover_and_get_fee(transaction),
           {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do
        {:ok, %{txhash: tx_hash, blknum: blknum, txindex: tx_index}}
      end

    result_with_logging(result)
  end

  @spec submit_batch(list(binary)) :: submit_result()
  def submit_batch(transactions) do
    case recover_transactions(transactions) do
      recovered_transactions when is_list(recovered_transactions) ->
        do_submit_batch(recovered_transactions)

      input_error ->
        # if we can't recover transactions we break off!
        input_error
    end
  end

  @spec get_filtered_fees(list(pos_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported}
  def get_filtered_fees(tx_types, currencies) do
    result =
      case FeeServer.current_fees() do
        {:ok, fees} ->
          FeeFilter.filter(fees, tx_types, currencies)

        error ->
          error
      end

    result_with_logging(result)
  end

  defp do_submit_batch(recovered_transactions) do
    number_of_transactions = Enum.count(recovered_transactions)

    {api_result, processing_result_num} =
      recovered_transactions
      |> State.exec_batch()
      |> Enum.reduce({[], number_of_transactions}, fn
        {tx_hash, blknum, tx_index}, {tx_result_acc, success_identifier} ->
          {[%{txhash: tx_hash, blknum: blknum, txindex: tx_index} | tx_result_acc], success_identifier - 1}

        error_tuple, {tx_result_acc, success_identifier} ->
          {[error_tuple | tx_result_acc], success_identifier}
      end)

    processing_result_type =
      case processing_result_num do
        0 -> :ok
        ^number_of_transactions -> :failed
        _ -> :mixed
      end

    {api_result, processing_result_type}
  end

  defp is_supported(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{}}}) do
    {:error, :transaction_not_supported}
  end

  defp is_supported(%Transaction.Recovered{}), do: :ok

  defp result_with_logging(result) do
    _ = Logger.debug(" resulted with #{inspect(result)}")
    result
  end

  defp recover_transactions(transactions) do
    recover_transactions(transactions, [])
  end

  defp recover_transactions([], acc) do
    Enum.reverse(acc)
  end

  defp recover_transactions([transaction | transactions], acc) do
    result = recover_and_get_fee(transaction)

    case result do
      {:error, _} = error -> error
      {:ok, data} -> recover_transactions(transactions, [data | acc])
    end
  end

  defp recover_and_get_fee(transaction) do
    with {:ok, recovered_tx} <- Transaction.Recovered.recover_from(transaction),
         :ok <- is_supported(recovered_tx),
         {:ok, fees} <- FeeServer.accepted_fees() do
      fees = Fees.for_transaction(recovered_tx, fees)
      {:ok, {recovered_tx, fees}}
    end
  end
end
