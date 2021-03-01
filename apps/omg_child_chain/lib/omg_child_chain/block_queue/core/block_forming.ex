defmodule OMG.ChildChain.BlockQueue.Core.BlockForming do
  alias OMG.ChildChain.BlockQueue.Core
  require Logger

  @moduledoc """
  Core helper module for block forming logic
  """
  @spec should_form_block?(Core.t(), non_neg_integer()) :: boolean() | {false, Time.t()}
  def should_form_block?(state, pending_txs_count) do
    # e.g. if we're at 15th Ethereum block now, last enqueued was at 14th, we're submitting a child chain block on every
    # single Ethereum block (`block_submit_every_nth` == 1), then we could form a new block (`it_is_time` is `true`)
    is_empty_block = pending_txs_count == 0
    it_is_time = state.parent_height - state.last_enqueued_block_at_height >= state.block_submit_every_nth

    met_transaction_number_limit = pending_txs_count >= state.block_has_at_least_txs_in_block
    should_form_block = it_is_time and met_transaction_number_limit and !state.wait_for_enqueue and !is_empty_block

    should_form_block =
      case {should_form_block, state.force_block_submission_countdown} do
        {false, nil} ->
          # if only the block_has_at_least_txs_in_block is not met, the caller should start the timer
          case it_is_time and !state.wait_for_enqueue and !is_empty_block do
            true ->
              {false, Time.utc_now()}

            _ ->
              false
          end

        {false, force_block_submission_countdown} ->
          !state.wait_for_enqueue and !is_empty_block and it_is_time and
            Time.diff(Time.utc_now(), force_block_submission_countdown, :millisecond) >
              state.force_block_submission_after_ms

        {true, _} ->
          should_form_block
      end

    log(state, it_is_time, is_empty_block, should_form_block)

    should_form_block
  end

  defp log(state, it_is_time, is_empty_block, false) do
    do_log(state, it_is_time, is_empty_block)
  end

  defp log(state, it_is_time, is_empty_block, {false, _}) do
    do_log(state, it_is_time, is_empty_block)
  end

  defp log(_, _, _, _) do
    :ok
  end

  defp do_log(state, it_is_time, is_empty_block) do
    log_data = %{
      parent_height: state.parent_height,
      last_enqueued_block_at_height: state.last_enqueued_block_at_height,
      block_submit_every_nth: state.block_submit_every_nth,
      wait_for_enqueue: state.wait_for_enqueue,
      it_is_time: it_is_time,
      is_empty_block: is_empty_block,
      force_block_submission_after_ms: state.force_block_submission_after_ms
    }

    case state.force_block_submission_countdown do
      nil ->
        Logger.debug("Skipping forming block because: #{inspect(log_data)}")

      _ ->
        Map.merge(log_data, %{
          force_block_submission_countdown_diff:
            Time.diff(Time.utc_now(), state.force_block_submission_countdown, :millisecond)
        })

        Logger.debug("Skipping forming block because: #{inspect(log_data)}")
    end
  end
end
