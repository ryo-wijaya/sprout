### Setup

- This truffle project is configured to run on port localhost:7545 and has been tested with Ganache 2.7.1.0

### Truffle commands

1. `truffle unbox` / `truffle init` - Initialize truffle workspace
2. `truffle compile` -> `truffle migrate` - Compile and deploy contracts on the blockchain
3. `truffle test` - run all unit tests
4. `truffle test ./test/test_market.js` - run unit test on a specific file

### Helpers

1. `truffle compile && truffle migrate` - shorthand to compile and migrate

### Dependencies

1. bn.js: 5.2.1
2. truffle-assertions: 0.9.2
