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

defmodule OMG.DB.ReleaseTasks.SetKeyValueDBTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias OMG.DB.ReleaseTasks.SetKeyValueDB

  @app :omg_db

  setup do
    {:ok, pid} = __MODULE__.System.start_link([])
    nil = Process.put(__MODULE__.System, pid)
    :ok
  end

  test "if environment variables get applied in the configuration" do
    test_path = "/tmp/YOLO/"
    release = :child_chain
    :ok = __MODULE__.System.put_env("DB_PATH", test_path)

    capture_log(fn ->
      config = SetKeyValueDB.load([], release: release, system_adapter: __MODULE__.System)
      path = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:path)
      assert path == test_path <> "#{release}"
    end)
  end

  test "if default configuration is used when there's no environment variables" do
    capture_log(fn ->
      config = SetKeyValueDB.load([], release: :child_chain, system_adapter: __MODULE__.System)
      path = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:path)

      assert path == Path.join([System.get_env("HOME"), ".omg/data"]) <> "/child_chain"
    end)
  end

  defmodule System do
    def start_link(args), do: GenServer.start_link(__MODULE__, args, [])
    def get_env(key), do: __MODULE__ |> Process.get() |> GenServer.call({:get_env, key})
    def put_env(key, value), do: __MODULE__ |> Process.get() |> GenServer.call({:put_env, key, value})
    def init(_), do: {:ok, %{}}

    def handle_call({:get_env, key}, _, state) do
      {:reply, state[key], state}
    end

    def handle_call({:put_env, key, value}, _, state) do
      {:reply, :ok, Map.put(state, key, value)}
    end
  end
end
