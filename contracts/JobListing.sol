pragma solidity ^0.5.0;
import "./User.sol";
import "./Escrow.sol";

contract JobListing {
    
    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //

    enum JobStatus {
        CLOSED, // This is when the client closes the job, no more applications
        OPEN, // This is when the client creates the job, open for applications
        ONGOING, // This is when the client accepts an application and the job is ongoing
        COMPLETED, // This is when the freelancer marks the job as complete
        PERMANENTLY_CLOSED // This is when the client accepts the job as complete, this job is done and uninteractable
    }

    /**
    * Ideally there are off-chain schedulers to enforce the various time contraints of the application. This can include:
    * - Enforcing freelancer job completion before the stipulated end time, and refunding the client if this condition is not met
    * - Enforcing a limited time between freelancer job completion and client job completion acceptance or a start of a dispute, and refunding the freelancer if this condition is not met
    * - Enforcing a limited time between the start of a dispute and the end of a dispute (See DAO for more information)
    */
    struct Job {
        uint256 clientId;
        uint256 acceptedFreelancerId;
        uint256 paymentId; // This is the paymentId from the escrow contract
        string title;
        string description;        
        uint256 endTime;
        uint256 reward;
        JobStatus status;
    }

    struct Application {
        uint256 freelancerId;
        string proposal; // What the freelancer feels makes them qualified to take the job for example
        bool isAccepted;
    }

    User userContract;
    Escrow escrowContract;

    // The number of tokens client must stake in the potential event of a dispute (business rule)
    uint256 public stakedTokens;

    uint256 private jobCount = 0;
    mapping(uint256 => Job) public jobs; // Get job details here by jobId
    // This is a mapping of job -> applications -> application
    mapping(uint256 => mapping(uint256 => Application)) public jobApplications;
    // This is to keep track of the number of applications for a job
    mapping(uint256 => uint256) private jobApplicationCounts;
    // keep track of if a freelancer has already applied for a job
    mapping(uint256 => mapping(uint256 => bool)) private hasApplied;

    constructor(address userAddress, address escrowAddress, uint256 _stakedTokens) public {
        userContract = User(userAddress);
        escrowContract = Escrow(escrowAddress);
        stakedTokens = _stakedTokens;
    }


    // ====================================================== EVENTS & MODIFIERS ========================================================== //
    event JobCreated(uint256 jobId, string title);
    event JobUpdated(uint256 jobId, string title);
    event JobClosed(uint256 jobId, string title);
    event JobOpened(uint256 jobId, string title);
    event ApplicationCreated(uint256 jobId, uint256 applicationId);
    event ApplicationAccepted(uint256 jobId, uint256 applicationId, uint256 freelancerId);
    event JobMarkedComplete(uint256 jobId, uint256 freelancerId);
    event JobAcceptedAsComplete(uint256 jobId, uint256 clientId);

    modifier userIdMatches(uint256 userId) {
        require(userContract.getAddressFromUserId(userId) == msg.sender, "This userId does not correspond to yourself");
        _;
    }

    modifier validJobId(uint256 jobId) {
        require(isValidJob(jobId), "Invalid Job ID");
        _;
    }

    modifier validApplicationId(uint256 jobId, uint256 applicationId) {
        require(applicationId > 0 && jobApplications[jobId][applicationId].freelancerId != 0, "Invalid Application ID");
        _;
    }


    // ============================================================== METHODS ============================================================= //
    /**
    * @dev Client can create a new job.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - Only clients can create jobs
    * - The endTime is at least 3 days in the future
    *
    * @param clientId The unique identifier of the client creating the job.
    * @param title The title of the job.
    * @param description The description of the job.
    * @param endTime The end time of the job, in Unix epoch time.
    * @param reward The reward for completing the job, in NT (SproutToken)
    */
    function createJob(uint256 clientId, string memory title, string memory description, uint256 endTime, uint256 reward) public userIdMatches(clientId) {
        require(userContract.isClient(clientId), "Only clients can create jobs");
        require(isValidEndTime(endTime), "The end time must be at least 3 days from now");

        jobCount++;
        Job memory newJob = Job({
            clientId: clientId,
            acceptedFreelancerId: 0, // This basically means null, userIds start from 1
            paymentId: 0, // This basically means null, paymentIds start from 1
            title: title,
            description: description,
            endTime: endTime,
            reward: reward,
            status: JobStatus.OPEN
        });
        jobs[jobCount] = newJob;

        emit JobCreated(jobCount, title);
    }

    /**
    * @dev Client can edit a job's details.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - Only the client who made the job post can edit it // recheck
    * - Only a job that has no applications can be edited
    * - The endTime is in the future
    *
    * @param clientId The unique identifier of the client.
    * @param jobId The unique identifier of the job to be updated.
    * @param title The new title of the job.
    * @param description The new description of the job.
    * @param endTime The new end time of the job, in Unix epoch time.
    * @param reward The new reward for the job, in NT (SproutToken)
    */
    function updateJob(uint256 clientId, uint256 jobId, string memory title, string memory description, uint256 endTime, uint256 reward) public userIdMatches(clientId) validJobId(jobId) {
        Job storage job = jobs[jobId];

        require(job.clientId == clientId, "Only the client who made the job post can edit it."); // this is a recheck for userIdMatches
        require(job.status != JobStatus.ONGOING && job.status != JobStatus.COMPLETED, "Job is ONGOING or COMPLETED and cannot be edited.");
        require(isValidTime(endTime), "The end time must be in the future.");

        // Check if there are applications for the job
        bool hasApplications = false;
        for(uint256 i = 1; i <= jobApplicationCounts[jobId]; i++) {
            if(jobApplications[jobId][i].freelancerId != 0) {
                hasApplications = true;
                break;
            }
        }

        // Jobs with applications cannot be edited
        require(!hasApplications, "Job that has applications cannot be edited.");
        
        job.title = title;
        job.description = description;
        job.endTime = endTime;
        job.reward = reward;

        emit JobUpdated(jobId, title);
    }


    /**
    * @dev Clients can close a job and re-open it some time in the future.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - Once a job is closed, applications are paused
    * - A job that is ongoing cannot be closed
    * - Only the client who posted the job can close it (recheck)
    *
    * @param clientId The unique identifier of the client.
    * @param jobId The unique identifier of the job to be closed.
    */

    function closeJob(uint256 clientId, uint256 jobId) public validJobId(jobId) userIdMatches(clientId) {
        require(jobs[jobId].clientId == clientId, "Only the client who posted the job can close it."); // this is a recheck for userIdMatches
        require(jobs[jobId].status == JobStatus.OPEN, "This job is either OPEN or currently ongoing and cannot be closed.");

        jobs[jobId].status = JobStatus.CLOSED;
        
        emit JobClosed(jobId, jobs[jobId].title);
    }


    /**
    * @dev Clients can re-open a closed job.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - The job must be in the CLOSED status
    * - Only the client who posted the job can re-open it
    * - The endTime must be in the future
    *
    * @param clientId The unique identifier of the client.
    * @param jobId The unique identifier of the job to be reopened.
    */
    function reopenJob(uint256 clientId, uint256 jobId) public validJobId(jobId) userIdMatches(clientId) {
        Job storage job = jobs[jobId];

        require(jobs[jobId].clientId == clientId, "Only the client who posted the job can re-open it."); // this is a recheck for userIdMatches
        require(jobs[jobId].status == JobStatus.CLOSED, "This job is not currently CLOSED.");
        require(isValidTime(job.endTime), "The end time must be in the future.");

        job.status = JobStatus.OPEN;

        emit JobOpened(jobId, jobs[jobId].title); 
    }


    /**
    * @dev Freelancers can apply to an open job post from a Client.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - The job must be open for applications
    * - Only freelancers can apply
    * - The freelancer and client cannot have the same address
    * - A freelancer can only apply to a unique job post once
    *
    * @param freelancerId The unique identifier of the freelancer applying for the job.
    * @param jobId The unique identifier of the job.
    * @param proposal The proposal submitted by the freelancer for the job.
    */
    function applyForJob(uint256 freelancerId, uint256 jobId, string memory proposal) public userIdMatches(freelancerId) validJobId(jobId) {
        require(jobs[jobId].status == JobStatus.OPEN, "Job is not open for applications");
        require(userContract.isFreelancer(freelancerId), "Only freelancers can take jobs.");
        require(!userContract.haveSameAddress(freelancerId, jobs[jobId].clientId), "Freelancer and client cannot have the same address");
        require(!hasApplied[jobId][freelancerId], "You have already applied for this job.");

        // Create the application
        Application memory newApplication = Application({
            freelancerId: freelancerId, 
            proposal: proposal,
            isAccepted: false
        });

        // Associate the application to the relevant mappings
        jobApplicationCounts[jobId]++;
        uint256 applicationIdForJob = jobApplicationCounts[jobId];
        jobApplications[jobId][applicationIdForJob] = newApplication;
        hasApplied[jobId][freelancerId] = true;

        emit ApplicationCreated(jobId, jobApplicationCounts[jobId]);
    }

    /**
    * @dev Clients can accept a specific job application for the job.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - The applicationId must be valid
    * - The job must be OPEN
    * - The application must not be tied to a freelancer with the same address (re-check)
    * - Only the client who posted the job can accept the application
    * - Once the application is accepted, the reward will be transferred to the escrow contract
    * - Client must have enough tokens to pay the reward + staked tokens in the event of a dispute (THIS WILL BE CHECKED IN THE ESCROW)
    *
    * @param clientId The unique identifier of the client.
    * @param jobId The unique identifier of the job.
    * @param applicationId The unique identifier of the application being accepted.
    */
    function acceptApplication(uint256 clientId, uint256 jobId, uint256 applicationId) public userIdMatches(clientId) validJobId(jobId) validApplicationId(jobId, applicationId) {
        Job storage job = jobs[jobId];
        Application storage application = jobApplications[jobId][applicationId];

        require(job.status == JobStatus.OPEN, "The job is not open.");
        require(job.clientId == clientId, "You are not the client who posted this job."); // this is a recheck for userIdMatches
        require(!userContract.haveSameAddress(application.freelancerId, job.clientId), "You are both the freelancer and the client, you cannot accept your own job application");

        // Call the escrow contract to hold the reward + staked tokens in escrow
        uint256 paymentId = escrowContract.initiatePayment(job.clientId, application.freelancerId, jobId, job.reward + stakedTokens);

        application.isAccepted = true;
        job.status = JobStatus.ONGOING;
        job.acceptedFreelancerId = application.freelancerId;
        job.paymentId = paymentId; // Associate the paymentId returned from the escrow to the job

        emit ApplicationAccepted(jobId, applicationId, application.freelancerId);
    }

    /**
    * @dev Freelancers can mark a job as complete after they have finished working on it.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - The job must be in the ongoing state
    * - Only the freelancer tied to this job via an accepted application can complete the job
    * - The job should then be marked as completed
    *
    * @param freelancerId The unique identifier of the freelancer.
    * @param jobId The unique identifier of the job being marked as complete.
    */
    function freelancerCompletesJob(uint256 freelancerId, uint256 jobId) public userIdMatches(freelancerId) validJobId(jobId) {
        Job storage job = jobs[jobId];

        require(job.acceptedFreelancerId == freelancerId, "You are not the accepted freelancer for this job."); // this is a recheck for userIdMatches
        require(job.status == JobStatus.ONGOING, "The job must be of status ONGOING");
        
        // Mark the job as completed by the freelancer
        job.status = JobStatus.COMPLETED;

        emit JobMarkedComplete(jobId, freelancerId);
    }

    /**
    * @dev Clients can accept a completed job if they are satisfied with it.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The jobId must be valid
    * - The job must be marked as completed
    * - Only the client who posted this job can accept the job completion
    *
    * @param clientId The unique identifier of the client.
    * @param jobId The unique identifier of the job being accepted as complete.
    */
    function clientAcceptsJobCompletion(uint256 clientId, uint256 jobId) public userIdMatches(clientId) validJobId(jobId) {
        Job storage job = jobs[jobId];

        require(job.clientId == clientId, "You are not the client who posted this job.");
        require(job.status == JobStatus.COMPLETED, "This job has not been marked as completed by the freelancer.");

        // Call the escrow contract to release the funds to the freelancer and refund the staked tokens to the client
        escrowContract.confirmDelivery(job.paymentId, true);

        // Permanently close the job
        job.status = JobStatus.PERMANENTLY_CLOSED;

        emit JobAcceptedAsComplete(jobId, clientId);
    }

    /**
    * @dev Return the job details (Meant for FE use as a custom getter)
    * 
    * Considerations:
    * - The jobId must be valid
    *
    * @param jobId The unique identifier of the job whose details are being requested.
    * @return tuple of the details of the specified job including clientId, acceptedFreelancerId, title, description, endTime, reward, and status.
    */
    function getJobDetails(uint256 jobId) public view validJobId(jobId) returns(uint256, uint256, string memory, string memory, uint256, uint256, JobStatus) {
        Job memory job = jobs[jobId];
        return (job.clientId, job.acceptedFreelancerId, job.title, job.description, job.endTime, job.reward, job.status);
    }

    /**
    * @dev Return the job application details (Meant for FE use as a custom getter)
    * 
    * Considerations:
    * - The jobId must be valid
    * - The jobId application must be valid
    *
    * @param jobId The unique identifier of the job.
    * @param applicationId The unique identifier of the application.
    * @return tuple of the details of the specified application including freelancerId, proposal, and isAccepted status.
    */
    function getApplicationDetails(uint256 jobId, uint256 applicationId) public view validJobId(jobId) validApplicationId(jobId, applicationId) returns(uint256, string memory, bool) {
        Application memory application = jobApplications[jobId][applicationId];
        return (application.freelancerId, application.proposal, application.isAccepted);
    }

    /**
    * @dev Return the number of applicants for a job
    * 
    * Considerations:
    * - The jobId must be valid
    *
    * @param jobId The unique identifier of the job.
    * @return uint256 count of applications for the specified job.
    */
    function getApplicationCountForJob(uint256 jobId) public view validJobId(jobId) returns(uint256) {
        return jobApplicationCounts[jobId];
    }

    /**
    * @dev Check if a specific job is completed
    * 
    * Considerations:
    * - The jobId must be valid
    *
    * @param jobId The unique identifier of the job.
    * @return bool indicating if the job is completed.
    */
    function isJobCompleted(uint256 jobId) public view validJobId(jobId) returns(bool) {
        return jobs[jobId].status == JobStatus.COMPLETED;
    }

    /**
    * @dev Check if a specific job is closed
    * 
    * Considerations:
    * - The jobId must be valid
    *
    * @param jobId The unique identifier of the job.
    * @return bool indicating if the job is permanently closed.
    */
    function isJobClosed(uint256 jobId) public view validJobId(jobId) returns(bool) {
        return jobs[jobId].status == JobStatus.PERMANENTLY_CLOSED;
    }

    /**
    * @dev Check if a job is ongoing
    * 
    * Considerations:
    * - The jobId must be valid
    *
    * @param jobId The unique identifier of the job.
    * @return bool indicating if the job is ongoing.
    */
    function isJobOngoing(uint256 jobId) public view validJobId(jobId) returns(bool) {
        return jobs[jobId].status == JobStatus.ONGOING;
    }

    /**
    * @dev Checks if a given startTime and endTime unix epoch int is valid
    * 
    * Considerations:
    * - The endTime must be at least 3 days from now (business rule)
    *
    * @param endTime The end time to validate, in Unix epoch time.
    * @return bool indicating if the end time is valid.
    */
    function isValidEndTime(uint256 endTime) public view returns (bool) {
        return (endTime >= block.timestamp + 3 days);
    }

    /**
    * @dev Checks if the endTime is in the future.
    *
    * @param endTime The end time to validate, in Unix epoch time.
    * @return bool indicating if the end time is in the future.
    */
    function isValidTime(uint256 endTime) public view returns (bool) {
        return (endTime >= block.timestamp);
    }

    /**
    * @dev Checks if a given jobId is valid.
    *
    * @param jobId The job ID to validate.
    * @return bool indicating if the job ID is valid.
    */
    function isValidJob(uint256 jobId) public view returns (bool) {
        return (jobId > 0 && jobId <= jobCount);
    }

    /**
    * @dev Retrieves the status of a job.
    *
    * @param jobId The ID of the job whose status is being queried.
    * @return JobStatus of the specified job.
    */
    function getJobStatus(uint256 jobId) public view validJobId(jobId) returns (JobStatus) {
        return jobs[jobId].status;
    }

    /**
    * @dev Retrieves the client ID associated with a job.
    *
    * @param jobId The ID of the job for which the client ID is being queried.
    * @return uint256 client ID associated with the specified job.
    */
    function getJobClient(uint256 jobId) public view validJobId(jobId) returns (uint256) {
        return jobs[jobId].clientId;
    }

    /**
    * @dev Retrieves the payment ID associated with a job.
    *
    * @param jobId The ID of the job for which the payment ID is being queried.
    * @return uint256 payment ID associated with the specified job.
    */
    function getJobPaymentId(uint256 jobId) public view validJobId(jobId) returns (uint256) {
        return jobs[jobId].paymentId;
    }

    /**
    * @dev Retrieves the freelancer ID associated with a job.
    *
    * @param jobId The ID of the job for which the freelancer ID is being queried.
    * @return uint256 freelancer ID associated with the specified job.
    */
    function getJobFreelancer(uint256 jobId) public view validJobId(jobId) returns (uint256) {
        return jobs[jobId].acceptedFreelancerId;
    }
}
