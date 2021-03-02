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

defmodule OMG.ChildChain.GasIntegration do
  @moduledoc false
  def create_gas_integration() do
    prod = Application.get_env(:omg_child_chain, :prod, false)

    gas = Code.ensure_loaded?(Gas)

    case {prod, gas} do
      {false, false} ->
        ast =
          quote do
            defmodule unquote(Gas) do
              defstruct low: 33.0, fast: 80.0, fastest: 85.0, standard: 50.0, name: "Geth"
              def unquote(:get)(_), do: "Elixir.Gas" |> String.to_atom() |> Kernel.struct!()
              def unquote(:integrations)(), do: []
            end
          end

        {{:module, Gas, _, _}, []} = Code.eval_quoted(ast)
        true = Code.ensure_loaded?(Gas)

      _ ->
        :skip
    end
  end
end
