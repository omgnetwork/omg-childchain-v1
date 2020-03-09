Feature: Invalid Standard Exits
  Scenario: Alice starts an invalid Standard Exit
    Given Alice deposited "12" ETH on the child chain
    And The child chain is secure
    When Alice sends Bob "11" ETH on the child chain
    And Alice starts a standard exit on the child chain from her recently spent input
    But Bob detects a new "invalid_exit"
    And Bob challenges an invalid exit
    And Alice tries to process exits
    Then The child chain is secure
    And Alice should have "12" ETH less on the blockchain
    And The Watcher resets after 20 Ethereum blocks
    And The child chain is secure

  Scenario: Alice starts an invalid Standard Exit from a non-deposit
    Given Alice received "12" ETH on the child chain
    And The child chain is secure
    When Alice sends Bob "11" ETH on the child chain
    And Alice starts a standard exit on the child chain from her recently spent input
    But Bob detects a new "invalid_exit"
    And Bob challenges an invalid exit
    And Alice tries to process exits
    Then The child chain is secure
    And Alice should have "0" ETH less on the blockchain
    And The Watcher resets after 20 Ethereum blocks
    And The child chain is secure

  Scenario: Alice almost succeeds with an invalid Standard Exit
    Given Alice deposited "12" ETH on the child chain
    And The child chain is secure
    When Alice sends Bob "11" ETH on the child chain
    And Alice starts a standard exit on the child chain from her recently spent input
    Then Bob detects a new "invalid_exit"
    And Bob detects a new "unchallenged_exit"
    # these two are here only to not end up with a broken chain
    And Bob challenges an invalid exit
    And Alice tries to process exits
    And The Watcher resets after 0 Ethereum blocks
    And The child chain is secure

  Scenario: Alice succeeds with an invalid Standard Exit
    Given Alice deposited "12" ETH on the child chain
    And The child chain is secure
    When Alice sends Bob "11" ETH on the child chain
    And Alice starts a standard exit on the child chain from her recently spent input
    Then Bob detects a new "invalid_exit"
    And Bob detects a new "unchallenged_exit"
    And Alice tries to process exits
    And Bob detects a new "invalidly_processed_exit"
    And The Watcher resets after 0 Ethereum blocks
    Then Bob detects a new "invalid_exit"
    And Bob detects a new "unchallenged_exit"
    And Bob detects a new "invalidly_processed_exit"
