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

ExUnit.configure(exclude: [common: true, integration: true, property: true, wrappers: true])
ExUnitFixtures.start()
# loading all fixture files from the whole umbrella project
ExUnitFixtures.load_fixture_files()
ExUnit.start()
OMG.ChildChain.GasIntegration.create_gas_integration()
{:ok, _} = Application.ensure_all_started(:fake_server)
{:ok, _} = Application.ensure_all_started(:briefly)
{:ok, _} = Application.ensure_all_started(:erlexec)
{:ok, _} = Application.ensure_all_started(:fake_server)
