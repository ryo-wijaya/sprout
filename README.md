### Info (Sprout)

- A blockchain-based job marketplace with dispute resolution, where clients and freelancers engage in job contracts with integrated escrow services and a DAO for handling disputes, all facilitated by smart contracts on the Ethereum network.

- See [Walkthrough Flow](docs/walkthrough.md) for more info

**Contributors:**

- Haris Bin Dzulkifli
- Pae En Yang
- Eugene Lim
- Cai Yuhan
- Ryo Wijaya
- Tan Wei Jie Ryan

### Requirements

1. `Truffle v5.11.5` (core: 5.11.5)
2. `Ganache v7.9.1`
3. `Solidity v0.5.16` (solc-js)
4. `Node v16.13.2`
5. `Web3.js v1.10.0`

### Setup

1. Ensure that you have the aforementioned node version.

   - Install truffle

   ```bash
   npm install truffle -g
   ```

   - Install Ganache from [Truffle Suite](https://trufflesuite.com/ganache/)

2. Install dependencies:

   - cd into project folder and install dependencies

   ```bash
   cd sprout
   npm i
   ```

3. Start up Ganache locally (Ensure that the server is running on port 7545).

4. Compile the Truffle project smart contracts into bytecode for the EVM:

   ```bash
   truffle compile
   ```

5. Deploy the Truffle project smart contracts on the local Ganache blockchain:

   ```bash
   truffle migrate
   ```

6. (Optionally) Run tests:

   - Run all 51 test cases

   ```bash
   truffle test
   ```

   - Or run a specific test file

   ```bash
   truffle test ./test/test_market.js
   ```

### Functional Workflow

#### User Registration and Job Management

1. **User Registration**: Users register themselves on the platform.
2. **Job Creation**: Clients post job listings with details about the work, reward, and requirements.
3. **Job Application**: Freelancers browse available jobs and apply to those they are qualified for.
4. **Job Acceptance and Escrow Setup**:
   - Clients review applications and accept the freelancer they find most suitable.
   - Upon acceptance:
     - The client transfers the job reward to the escrow.
     - The client stakes an X amount of tokens in the escrow as a safeguard in the event of a dispute.

#### Job Completion and Payment

5. **Job Completion**: The freelancer completes the job and submits it for the client's approval.
   - **If the Client Approves**:
     - The **freelancer is paid** the job reward from the escrow.
     - The **client is refunded** the staked tokens.
   - **If the Client Does Not Approve**:
     - The client must start a **dispute with the DAO**.

#### Dispute Resolution Process

6. **Dispute Handling**:
   - Reviewers, assumed to have access to dispute details and work done, vote in favor of the client or freelancer.
   - **Outcome if the Client Wins**:
     - The client is refunded the job's reward, but not the staked tokens.
   - **Outcome if the Freelancer Wins**:
     - The freelancer is paid the job reward.
     - The client is not refunded.
   - **Voter Rewards**:
     - At the end of voting, a limited and random selection of voters from the winning side are paid from the client's staked tokens.
     - Any remaining staked tokens are refunded to the client.

### Technical Specifications

The primary contracts include User, JobListing, JobReview, Escrow, DisputeResolutionDAO, and SproutToken.

1. The **User** contract manages user profiles and roles, categorizing participants as freelancers, clients, and reviewers.
2. The **JobListing** contract is central to the application, facilitating the creation, management, and completion of job listings. It links clients with freelancers and manages job applications and statuses.
3. The **Escrow** contract is pivotal for financial transactions, holding funds in escrow during job execution and releasing payments upon job completion or refunding in case of disputes. It uses the **SproutToken** contract, a custom ERC-20 token, for transactions.
4. The **JobReview** contract allows clients and freelancers to review each other post-job completion, thereby ensuring quality and accountability.
5. The **DisputeResolutionDAO** contract handles disputes that arise during job execution, with a voting mechanism for resolution and token rewards for participating reviewers.

### Assumptions

1. **Token Payout Amounts**: The deployer specifies the amount of tokens a Client must stake when accepting an application (for a potential dispute) and the number of tokens to be paid out to each winning voter. The maximum number of voters to be rewarded randomly will be calculated from there (see `migrations/2_deploy_contracts` and `contracts/DisputeResolutionDAO.sol` for more details). If there are not enough winning voters, all winning voters will be rewarded and the token balance from the staked tokens will be refunded to the client. It is assumed that the contract functions exist for the deployer to modify these values in the contract. This is not implemented as upgradability is not the focus of the project.

2. **Temporal Concerns**: Throughout the project, we assume an off-chain external service that can trigger events (similar to CRON jobs). These assumptions are made clearly where applicable in the code.

3. **Future Development**: To make the application business-viable, we assume that specific additional implementations are present when they are not (since this is not the focus of the project). These are indicated clearly in the contract code. Some examples are the ability to allow users to exchange SproutTokens for ETH, taking a very small commission fee to discourage spam and an off-chain user verification process.

4. **Trust and Security**: The application assumes a level of trust and security inherent in blockchain technology. Smart contracts are assumed to execute as intended without interference, and the integrity of transactions and interactions is maintained by the Ethereum blockchain.

5. **Token Economy**: The system's economy is based on SproutToken, an ERC-20 token. It is assumed that this token has value within the ecosystem and is accepted by users for payments and rewards. The escrow mechanism and dispute resolution process are heavily reliant on the token's usage and distribution.

6. **User Behavior and Participation**: The application assumes active participation from its users – clients posting jobs, freelancers applying for them, and reviewers participating in dispute resolutions. It also assumes a fair distribution of each user type, as well as a large enough number of users. The effectiveness of the dispute resolution process relies on the assumption that a sufficient number of unbiased reviewers will vote to resolve disputes fairly. Furthermore, it presumes that users will provide genuine reviews post-job completion, contributing to a trustworthy platform environment.
