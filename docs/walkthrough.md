# Walkthrough Text

This is the walkthrough text requirement specified under **Code Implementation - Documentation**.

**Sprout**: A blockchain-based job marketplace with dispute resolution, where clients and freelancers engage in job contracts with integrated escrow services and a DAO for handling disputes, all facilitated by smart contracts on the Ethereum network.

**Basic flow**: Clients can post jobs that freelancers can apply for. Funds will be managed in a escrow. Reviews can be made post-job completion and there is a DAO to manage disputes. More details on the functional workflow can be found in the README file. 

* This document contains a surface level overview of the contract functions. For more details on the design, please refer to Group 4's project report.

* This demo flow is designed for https://remix.ethereum.org/ and will focus on the happy paths for the application. For proof of exception path validations, kindly refer to the test cases under `/test`.

* This document will also be included in the report and in the repository for reference.



A link to the demo video pertaining to this walkthrough can be found here: https://drive.google.com/file/d/1ta9Jar93Ac8LM5Px_m-h0kAmhdyQrMaK/view?usp=sharing. Each section has been updated with the relevant timestamps.



## Overview of contract functions

Note that many of these functions, while public, can only be called with a certain access right. For example, Escrow contract functions can only be called by the JobListing and DisputeResolutionDAO contract that has their addresses set by the contract owner.



**SproutToken.sol (Native Token Contract with ERC20 Composition)**

1. `getCredit`
2. `checkCredit`
3. `transferCredit`
4. `transferFrom`
5. `approve`



**User.sol (User Management Contract)**

1. `register`
2. `updateUserDetails`
3. `getUserDetails`
4. `updateRating`
5. `getTotalUsers`
6. `getAddressFromUserId`
7. `haveSameAddress`
8. `isClient`
9. `isFreelancer`
10. `isReviewer`
11. `transferOwnership`
12. `withdrawEther`
13. `setJobReviewAddress`



**JobListing.sol (Job Management Contract)**

1. `createJob`
2. `updateJob`
3. `closeJob`
4. `reopenJob`
5. `applyForJob`
6. `acceptApplication`
7. `freelancerCompletesJob`
8. `clientAcceptsJobCompletion`
9. `getJobDetails`
10. `getApplicationDetails`
11. `getApplicationCountForJob`
12. `isJobCompleted`
13. `isJobClosed`
14. `isJobOngoing`
15. `isValidEndTime`
16. `isValidTime`
17. `isValidJob`
18. `getJobStatus`
19. `getJobClient`
20. `getJobPaymentId`
21. `getJobFreelancer`



**Escrow.sol (Escrow Management Contract)**

1. `initiatePayment`
2. `confirmDelivery`
3. `refundPayment`
4. `rewardVoter`
5. `refundTokenBalance`
6. `getClientId`
7. `getFreelancerId`
8. `getJobId`
9. `getBalance`
10. `getCurrentStatus`
11. `setJobListingAddress`
12. `setDisputeResolutionDAOAddress`



**JobReview.sol (Job Review Management Contract)**

1. `createFreelancerReview`
2. `createClientReview`
3. `getFreelancerRating`
4. `getClientRating`
5. `getReviewDetails`



**DisputeResolutionDAO.sol (DAO Contract)**

1. `startDispute`
2. `vote`
3. `resolveDispute`
4. `manuallyTriggerEndVoting`
5. `distributeTokensToVoters`



## 1. Deployment (02:00)

<u>**Perform the following actions with 1 account and remember the account address. This will be the contract owner for some of the contracts. Remember this user as (User 0)**</u>

1. **Compile all smart contracts** with env `Remix VM (Shanghai)` and compiler version `0.5.17+commit.d19bba13`

2. **Deploy** `User.sol`

3. **Deploy** `SproutToken.sol`

4. **Deploy** `Escrow.sol` with the addresses of the User and SproutToken contracts

   1. Specify `10` for the `_stakedTokens` parameter

   2. Specify  `1` for the `_eachVoterReward` parameter

   * Notes
     * The owner is able to dynamically specify the number of tokens a Client must stake for each job, these tokens will come into effect in the event of a dispute only. The owner can also specify the number of tokens a winning voter should get in the event of a dispute's voting conclusion.
     * For simplicity, we define the values above. This means that the contract deployer has decided that up to 10 voters from the winning pool will be rewarded 1 token each upon voting conclusion. In our project these values are specified in the deployment script, but in Remix we define it manually here.

5. **Deploy** `JobListing.sol` with the addresses of the User and Escrow contracts

   1. Specify `10` for the `_stakedTokens` parameter

6. **Deploy** `JobReview.sol` with the addresses of the User and JobListing contracts

7. **Deploy** `DisputeResolutionDAO.sol` with the addresses of the User, JobListing, and Escrow contracts

   1. Specify `10` for the `_maxNumberOfWinners` parameter

8. **Set the Escrow contract's JobListing and disputeResolutionDAO addresses** for access control

   1. Call `setJobListingAddress`

   2. Specify the deployed jobListing and disputeResolutionDAO contract addresses

9. **Set the user contract's jobReview address** for ratings management

   1. Call `setJobReviewAddress`




## 2. SproutToken Contract - Obtain Tokens (06:06)

This is our native ERC20 token contract.

<u>**Perform the following with new accounts  (for `i` from  Users`1-5`)**</u>

1. Top up 100 credits each with ETH (1 ETH gets you 100 tokens, and 1 ETH is 10^18 wei)

   1. Call `getCredit(user ${i}'s address, 1000000000000000000)` 

   * Notes
     * This exchange rate is arbitrarily chosen for demo purposes



## 3. User Contract (07:51)

This contract manages user registration. A user can be either a Freelancer, client, or Reviewer.

**<u>Perform the following with the Client account to be (User 1)</u>**

1. **Register as a Client**

   1. Call `register(1, 'client', 'name', 'email@example.com', 'bio1')` with `1000 Finney` (0.01 Eth)

   * Validations
     * The `UserType` enum value is valid
     * The `username` is valid
     * Each account address can only have one of each `UserType` profile
     * Eth fee is an anti-spam measure
   * Notes
     * We assume that there is a way for users to securely log in (e.g. Off-chain session management, Ethereum wallet authentication, ...)
     * We omit password for technical simplicity, since storing sensitive information on-chain is not good practice and we assume the implementation of other 3rd party verification services

2. **Update user details to expand on the profile biography**

   1. Call `updateUserDetails(1, 'newName', 'client@example.com', bioRef)`

   2. bioRef: Creative director and digital art enthusiast with a decade of experience in the dynamic world of digital media and graphic design. Passionate about exploring the intersection of technology and art, particularly in 3D animation and virtual reality experiences. Here to collaborate with innovative freelancers who are skilled in pushing the boundaries of digital artistry and bringing imaginative concepts to a global audience

   * Validations
     * Only the owner of the profile can perform this. This is checked via matching the caller address with the passed in `userId`

3. **Frontend views the clients profile**

   * Call `getUserDetails(1)`

4. **Frontend gets the total number of users (e.g. for site metrics)**
   
   * Call `getTotalUsers()`
   
5. **Other functions** (do not execute)
   
   1. `transferOwnership` - Transfer ownership of the contract to another address
   2. `withdrawEther` - Withdraw Ether held in this contract to the owner's address (so funds will not be trapped)



**<u>Perform the following with the Freelancer account to be (User 2)</u>**

6. **Register as a Freelancer**

1. Call `register(0, 'freelancer', 'name', 'freelancer@example.com', 'An aspiring professional artist with a speciality in digital art')` with `1000 Finney` (0.01 Eth)



<u>**Perform the following with the Reviewer accounts to be, remember these addresses as (Users 3 - 5). These will be reviewers.**</u>

7. **Register as a Reviewer (for `i` from  Users`1-3`)**

   1. Call `register(2, 'reviewer${i}', 'name', 'reviewer${i}@example.com', 'I am reviewer ${i}')` with `1000 Finney` (0.01 Eth)

   * Notes
     * The previous users could also have registered Reviewer accounts. However, since the intention is the demo voting during a dispute between those user accounts, only accounts from other addresses will be permitted to vote.



## 4. JobListing Contract - No Dispute (13:15)

This contract manages the flow of job creation, application, and completion. A job can either be closed, open, ongoing, completed or permanently closed. 

**<u>Perform the following with the Client account (User 1)</u>**

1. **Create a Job**

   1. `Call createJob(1, 'New Art Commissioning', 'placeholder description', 1701705600, 15)`

   * Validations
     * The userID must be valid and must correspond to the caller's address
     * Only account of `UserType` client can create jobs
     * The specified endTime is at least 3 days in the future

   * Notes
     * The unix timestamp given corresponds to 5th Dec 2023
     * We assume that there are off-chain schedulers like the Ethereum Alarm Clock to perform the following validations
       * Freelancers must complete the job before the stipulated end time, else the client will be refunded
       * Once a freelancer completes a job, clients have x amount of time to accept the completion or start a dispute before the tokens are automatically paid to the freelancer

2. **Update job details to expand on job scope** (PUT)

   1. Call `updateJob(1, 1, 'New Art Commissioning', 'I need someone with both gardening and art to draw an apple tree', 1701705600, 15)`

   * Validations
     * The userID must be valid and must correspond to the caller's address
     * JobID must be valid
     * Only the client who created the job can update it
     * Only jobs with no applications can be updated
       * This is to prevent nasty surprises for the freelancers

3. **Frontend views jobs and a job's details**

   1. Call `jobs` mapping
   2. Call `getJobDetails(1)`

4. **Client closes the job**

   1. Call `closeJob(1, 1)`

   * Validations
     * The userID must be valid and must correspond to the caller's address
     * JobID must be valid
     * The job must not be in the ongoing state
     * Only the client who created the job can close it
   * Notes
     * For example, a large client might want to pre-create jobs in bulk, close them, and open them at specific times (e.g. Event management company)
     * Once closed, applications to it are disabled

5. **Client re-opens the job** 

   1. Call `reopenJob(1, 1)`

   * Validations 
     * The userID must be valid and must correspond to the caller's address
     * JobID must be valid
     * The job must be currently in the closed state
     * The endTime must still be in the future
       * Otherwise the client will have to update the job first
     * Only the client who created the job can close it



<u>**Perform the following with the Freelancer account (User 2)**</u>

6. **Freelancer applies for the job**

   1. Call `applyForJob(2, 1, 'Check out my profile, I garden and draw, hence I might be a good fit')`

   * Validations
     * The userID must be valid and must correspond to the caller's address
     * JobID must be valid
     * The job must be currently in the opened state
     * Only freelancers can apply
     * The freelancer and client cannot have the same address, meaning if Account A has both a freelancer and a client account, Account A's freelancer account cannot apply to Account A's client's job
     * A freelancer cannot make repeated applications to the same job post



<u>**Perform the following with the Client account (User 1)**</u>

7. **Frontend displays the number of applications per job**
   1. Call `getApplicationCountForJob(1)`

8. **Frontend displays all applications for a Client's job**

   1. Call `jobApplications(1)` mapping

9. **Frontend display a specific application's details**

   1. Call `getApplicationDetails(1, 1)`

10. **Client accepts a specific freelancer's application**

    1. Call `acceptApplication(1, 1, 1)`

    * Validations
      * The userID must be valid and must correspond to the caller's address
      * JobID must be valid
      * The job must be currently in the opened state
      * Only the client who posted the job can accept the application
      * Client must have enough tokens to cover the reward + the amount of staked tokens needed as deposit in the event of a dispute (in this case its 15 + 10)
    * Notes
      * This will call the Escrow contract's `initiatePayment` function to transfer the tokens to the escrow.
        * The escrow's balance will now be 25 tokens and the status will be AWAITING PAYMENT
      * Note that the JobListing address was set by the contract owner in the Escrow contract in the beginning, in the interest of access control, the `initiatePayment` function CANNOT be called publicly, only be this specific JobListing contract instance.
      * The job is marked as ongoing after this and will not take in anymore applications



<u>**Perform the following with the Freelancer account (User 2)**</u>

11. **Freelancer completes the job**

    1. Call `freelancerCompletesJob(2, 1)`

    * Validations
      * The userID must be valid and must correspond to the caller's address
      * JobID must be valid
      * The job must be currently in the ongoing state
      * Only the freelancer tied to the accepted job application can complete the job
    * Notes
      * We assume that there is an avenue where the freelancer can show details of the completed work to the client. This platform may be on/off-chain.
      * The job is marked as completed after this



<u>**Perform the following with the Client account (User 1)**</u>

12. **Client finds the work satisfactory and accepts the job's completion**

    1. Call `clientAcceptsJobCompletion(1, 1)`

    * Validations
      * The userID must be valid and must correspond to the caller's address
      * JobID must be valid
      * The job must be currently in the completed state
      * Only the client who posted the job can accept the completion
    * Notes
      * This will call the Escrow contract's `confirmDelivery` function which pays the Freelancer the job's reward, and then refunds the staked 10 tokens to the client. This is because there was no dispute. 
        * The escrow's balance will now be 0 tokens and the payment will be marked as COMPLETE
      * The job is marked as permanently closed after this and the happy path is concluded



## 5. SproutToken Contract - No Dispute Check (27:33)

1. **Check the client's balance**
   1. Call `checkCredit(User 1's address)`
      * This should be 100 - 15 (job reward) = 85
2. **Check the freelancer's balance**
   1. Call `checkCredit(User 2's address)`
      * This should be 100 + 15 (job reward) = 115



## 6. JobReview Contract (28:43)

This contract manages review creation for both the freelancer and the client.

<u>**Perform the following with the Client account (User 1)**</u>

1. **Client creates a review for the freelancer**

   1. Call `createFreelancerReview(1, 2, 1, 4, 'The art is well drawn')`

   * Validations
     * All IDs must be valid, the clientId must correspond to the caller's address
     * Job must be in the permanently closed state
     * Rating must be an integer from 1-5
     * Only 1 review can be given per completed job



<u>**Perform the following with the Freelancer account (User 2)**</u>

1. **Freelancer creates a review for the client**

   1. Call `createClientReview(1, 2, 1, 5, 'The job description is clear and accurate')`

   * Validations
     * All IDs must be valid, the clientId must correspond to the caller's address
     * Job must be in the permanently closed state
     * Rating must be an integer from 1-5
     * Only 1 review can be given per completed job

2. **Frontend displays a user's reviews**

   1. Call `userToReviews` mapping

3. **Frontend displays a review's details**

   1. Call `getReviewDetails(1)`



## 7. User Contract - Check Updated Ratings (30:46)

Ratings can be made for each party after any job flow is completed, including ones with a dispute. Ratings are used as a badge of trust. Low client ratings can indicate that the client starts disputes often, possibly due to poor or changing job requirements which is blamed on the freelancer for example. Low freelancer ratings can indicate consistently poor work.

1. **Check the Client's current average rating**
   1. Call `getUserDetails(1)`
      * This should be 5 / 1 = 5
2. **Check the Freelancer's current average rating**
   1. Call `getUserDetails(2)`
      * This should be 4 / 1 = 4



## 8. JobListing Contract - With Dispute (32:06)

Previously we demo-ed the flow for a successful client-freelancer transaction without a dispute. Now we will set up an identical scenario, but this time the client does not choose to accept the job's completion. First, let's set up a similar scenario as before, this time **replacing every JobID with 2 instead of 1**.



**<u>Perform the following with the Client account (User 1)</u>**

1. **Create a Job**
   1. `Call createJob(1, 'New Art Commissioning', 'placeholder description', 1701705600, 15)`



<u>**Perform the following with the Freelancer account (User 2)**</u>

4. **Freelancer applies for the job**
   1. Call `applyForJob(2, 2, 'Check out my profile, I garden and draw, hence I might be a good fit')`



<u>**Perform the following with the Client account (User 1)**</u>

3. **Client accepts a specific freelancer's application**
   1. Call `acceptApplication(1, 2, 1)`



<u>**Perform the following with the Freelancer account (User 2)**</u>

11. **Freelancer completes the job**
    1. Call `freelancerCompletesJob(2, 2)`



## 9. DisputeResolutionDAO Contract (34:08)

This contract manages the creation of disputes, voting, and payouts after the dispute outcome.

* The client is not happy with the work for JobID 2 and wishes to start a dispute. The rules of a dispute are such:
  * Remember, the client has staked 10 tokens in the escrow for this scenario.
  * It is assumed that there is an avenue for the reviewers (or voters) to review details on the work done. This is assumed to be off-chain.
  * A dispute will last for 3 days and be open to voting from users of `userType` reviewer.
    * 3 is just an arbitrary number for simplicity
    * If the client gets more votes (APPROVE VOTE)
      * The client will be refunded the job reward
    * If the freelancer gets more votes (REJECTED VOTE)
      * The freelancer will be paid the job reward
    * Either way, upon voting conclusion
      * The 10 staked tokens by the client will be distributed to the winning voters
      * Since the contract owner has specified (upon contract deployment) that each winning voter's reward is 1 token, up to 10 voters from the winning pool will be rewarded
        * If there are less than 10 winning voters
          * The winning voters will be rewarded, and the balance from the staked tokens will be refunded to the client
        * If there are more than 10 winning voters
          * 10 random winning voters will be selected and rewarded. The client will not see a single staked token back
      * Hence, the staked tokens is a risk that a client takes that encourages them to only start disputes if they know there are most probably in the right. The client can then rate the freelancer badly. Ultimately it should be the client's job to select only freelancers with good reviews to perform the task, to reduce the chance of a dispute. 



**<u>Perform the following with the Client account (User 1)</u>**

1. **Client starts a dispute for a job (with ID 2)**

   1. Call `startDispute(1, 2)`

   * Validations
     * All IDs must be valid, the clientId must correspond to the caller's address
     * The job must not currently have an associated dispute
     * Only the client who created the job can start a dispute
     * The job must be in the completed state
   * Notes
     * This will open up voting for 3 days. Within these 3 days, the dispute is in the PENDING state



**<u>Perform the following with the reviewer accounts (Users 3-5)</u>**

2. **1 Reviewer votes for the client (APPROVE VOTE) and 2 Reviewers vote for the freelancer (REJECT VOTE)**

   1. Call `vote(3, 1, 1)`
   2. Call `vote(4, 1, 2)`
   3. Call `vote(5, 1, 2)`

   * Validations
     * All IDs must be valid, the reviewerId must correspond to the caller's address
     * Reviewers can only vote once per dispute
     * Reviewers cannot vote for a dispute where their address is tied to the same client or freelancer involved in the dispute
     * Dispute must be in the pending state
   * Notes
     * A vote cast after the stipulated endTime in the dispute will cause the vote to end and trigger the `resolveDispute` function discussed below. This is a form of passive closure. We also assume that there are off-chain external schedulers to enforce the closing and counting of votes automatically should the time come



**<u>Perform the following with the contract owner (User 0)</u>**

3. **Contract owner manually ends the voting**

   1. Call `manuallyTriggerEndVoting(1)`
      1. This overrides the stipulated endTime of the dispute to a past date and calls the same `resolveDispute` function discussed before

   * Notes
     * Ideally, this function shouldn't exist to preserve decentralization and also since there should be off-chain schedulers. But this is included here for demo purposes such that we can "skip time" and start counting votes. 

4. **`resolveDispute` Function called** (Not publicly callable)

   1. This currently  triggers when the `manuallyTriggerEndVoting` function is called or when a vote is cast after the voting period has ended.

   * Validations
     * The endTime stipulated in the dispute is in the past
     * The dispute is in the PENDING state
   * Notes
     * This tallies up the votes
       * If there are more APPROVE votes, the escrow contract's `refundPayment` function is called. This refunds the job's token reward back to the client instead of paying it to the freelancer. This DOES NOT refund the 10 staked tokens.
       * If there are more REJECT votes, the escrow contract's `confirmDelivery` function is called with the `withStakedTokens` flag set to false. This pays the freelancer the job's token reward.
     * At this point of time, the escrow's balance should ONLY contain the staked tokens. This is 10 tokens for this scenario. 
     * Since there are more votes in favor of the freelancer (2 REJECT - 1 APPROVE), the tokens are paid to the freelancer instead of being refunded to the client.
     * At the end of this function, the `distributeTokensToVoters` function is called passing in the winning vote

5. **`distributeTokensToVoters` Function called** (Not publicly callable)

   1. This is triggered by the `resolveDispute` function, and a winning vote (APPROVE or REJECT) is passed in.

   * Notes
     * REJECT is the winning vote. The pool size is 2. Hence, these 2 voters will be rewarded 1 token each from the balance of the 10 staked tokens by the client. The remaining 8 tokens will be refunded to the client.
     * Again note that if the pool size exceeds 10 tokens in this case, the winners will be randomly chosen from the winning pool and there will not be a single staked token left to refund the client with.
     * For the alternative flow where APPROVE is the winning vote, see the unit test cases in `/test`



## 10. SproutToken Contract - After Dispute Check (46:52)

1. **Check the client's balance** (previous balance was 85)
   1. Call `checkCredit(User 1's address)`
      * This should be 85 - 15 (job reward) - 2 (staked tokens) = 68
2. **Check the freelancer's balance** (previous balance was 115)
   1. Call `checkCredit(User 2's address)`
      * This should be 115 + 15 (job reward) = 130



## Conclusion (48:05)

Note that all the escrow functions to manage the flow of tokens is not publicly callable. In the beginning of the demo during deployment, there was access right control set up by the contract owner to ensure that only a specific instance of the JobListing and DisputeResolutionDAO contract can call these functions. 

This is the end of the demo, thank you for reaching up to this point and feel free to check the GitHub repository for more information.

