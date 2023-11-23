pragma solidity ^0.5.0;
import "./User.sol";
import "./Escrow.sol";

contract JobListing {
    
    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //

    enum JobStatus {
        CLOSED,
        OPEN,
        ONGOING,
        COMPLETED,
        PERMANENTLY_CLOSED
    }

    struct Job {
        uint256 clientId;
        uint256 acceptedFreelancerId; // This should be cleared after a job is done
        uint256 paymentId; // This is the paymentId from the escrow contract
        string title;
        string description;        
        uint256 endTime;
        uint256 reward;
        JobStatus status;
    }

    struct Application {
        uint256 freelancerId;
        string proposal;
        bool isAccepted;
    }

    User userContract;
    Escrow escrowContract;

    // The number of tokens client must stake in the potential event of a dispute (business rule)
    uint256 public stakedTokens;

    uint256 private jobCount = 0;
    mapping(uint256 => Job) jobs; // Get job details here by jobId
    // This is a mapping of job -> applications -> application
    // jobApplications[jobId] -> All the applications for that job
    // jobApplications[jobId][applicationId] -> A specific application for that job
    mapping(uint256 => mapping(uint256 => Application)) private jobApplications;
    // This is to keep track of the number of applications for a job
    mapping(uint256 => uint256) private jobApplicationCounts;
    // keep track of if a freelancer has already applied for a job
    mapping(uint256 => mapping(uint256 => bool)) private hasApplied;

    constructor(address userAddress, address escrowAddress, uint256 _stakedTokens) public {
        userContract = User(userAddress);
        escrowContract = Escrow(escrowAddress);
        stakedTokens = _stakedTokens;
    }
    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //



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
    // ====================================================== EVENTS & MODIFIERS ========================================================== //



    // ============================================================== METHODS ============================================================= //
    /**
    * Create a new job.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - Only clients can create jobs
    * - The endTime is at least 3 days in the future
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
    * Edit a job details.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - Only the client who made the job post can edit it // recheck
    * - Only a job that has no applications can be edited
    * - Do a check for the job to be not ongoing (The above condition makes this redundant but this is just for safety)
    * - The endTime is in the future
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

        // ideally this should be another field in the Job struct but lazy ah
        require(!hasApplications, "Job that has applications cannot be edited.");
        
        job.title = title;
        job.description = description;
        job.endTime = endTime;
        job.reward = reward;

        emit JobUpdated(jobId, title);
    }


    /**
    * A Client can close a job and re-open it some time in the future.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - Once a job is closed, applications are paused
    * - A job that is ongoing cannot be closed
    * - Only the client who posted the job can close it (recheck)
    */
    function closeJob(uint256 clientId, uint256 jobId) public validJobId(jobId) userIdMatches(clientId) {
        require(jobs[jobId].clientId == clientId, "Only the client who posted the job can close it."); // this is a recheck for userIdMatches
        require(jobs[jobId].status == JobStatus.OPEN, "This job is either OPEN or currently ongoing and cannot be closed.");

        jobs[jobId].status = JobStatus.CLOSED;
        
        emit JobClosed(jobId, jobs[jobId].title);
    }


    /**
    * A Client can re-open a closed job.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - The job must be in the CLOSED status
    * - Only the client who posted the job can re-open it
    * - The endTime must be in the future
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
    * A Freelancer can apply to an open job post from a Client.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - The job must be open for applications
    * - Only freelancers can apply
    * - The freelancer and client cannot have the same address
    * - A freelancer can only apply to a unique job post once
    */
    function applyForJob(uint256 freelancerId, uint256 jobId, string memory proposal) public userIdMatches(freelancerId) validJobId(jobId) {
        require(jobs[jobId].status == JobStatus.OPEN, "Job is not open for applications");
        require(userContract.isFreelancer(freelancerId), "Only freelancers can take jobs.");
        require(!userContract.haveSameAddress(freelancerId, jobs[jobId].clientId), "Freelancer and client cannot have the same address");
        require(!hasApplied[jobId][freelancerId], "You have already applied for this job.");

        Application memory newApplication = Application({
            freelancerId: freelancerId, 
            proposal: proposal,
            isAccepted: false
        });

        jobApplicationCounts[jobId]++;
        uint256 applicationIdForJob = jobApplicationCounts[jobId];
        jobApplications[jobId][applicationIdForJob] = newApplication;
        hasApplied[jobId][freelancerId] = true;

        emit ApplicationCreated(jobId, jobApplicationCounts[jobId]);
    }

    /**
    * A Client can accept a specific job application for the job.
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
    * - Client must have enough tokens to pay the reward + x tokens (in the event of a dispute) (THIS WILL BE CHECKED IN THE ESCROW)
    */
    function acceptApplication(uint256 clientId, uint256 jobId, uint256 applicationId) public userIdMatches(clientId) validJobId(jobId) validApplicationId(jobId, applicationId) {
        Job storage job = jobs[jobId];
        Application storage application = jobApplications[jobId][applicationId];

        require(job.status == JobStatus.OPEN, "The job is not open.");
        require(job.clientId == clientId, "You are not the client who posted this job."); // this is a recheck for userIdMatches
        require(!userContract.haveSameAddress(application.freelancerId, job.clientId), "You are both the freelancer and the client, you cannot accept your own job application");

        uint256 paymentId = escrowContract.initiatePayment(job.clientId, application.freelancerId, jobId, job.reward + stakedTokens);

        application.isAccepted = true;
        job.status = JobStatus.ONGOING;
        job.acceptedFreelancerId = application.freelancerId;
        job.paymentId = paymentId; // Associate the paymentId returned from the escrow to the job

        emit ApplicationAccepted(jobId, applicationId, application.freelancerId);
    }

    /**
    * A Freelancer can mark a job as complete after they have finished working on it.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - The jobId must be valid
    * - Only the freelancer tied to this job via an accepted application can complete the job
    * - The job should then be marked as completed
    */
    function freelancerCompletesJob(uint256 freelancerId, uint256 jobId) public userIdMatches(freelancerId) validJobId(jobId) {
        Job storage job = jobs[jobId];
        require(job.acceptedFreelancerId == freelancerId, "You are not the accepted freelancer for this job."); // this is a recheck for userIdMatches
        require(job.status == JobStatus.ONGOING, "The job must be of status ONGOING");
        job.status = JobStatus.COMPLETED;

        emit JobMarkedComplete(jobId, freelancerId);
    }

    /**
    * A Client can accept a completed job if they are satisfied with it.
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The jobId must be valid
    * - The job must be marked as completed
    * - Only the client who posted this job can accept the job completion
    */

    function clientAcceptsJobCompletion(uint256 clientId, uint256 jobId) public userIdMatches(clientId) validJobId(jobId) {
        Job storage job = jobs[jobId];

        require(job.clientId == clientId, "You are not the client who posted this job."); // this is a recheck for userIdMatches
        require(job.status == JobStatus.COMPLETED, "This job has not been marked as completed by the freelancer.");

        // Pay the freelancer the reward, and refund the staked 10 tokens to the client (indicated by 2nd argument as true)
        escrowContract.confirmDelivery(job.paymentId, true);

        job.status = JobStatus.PERMANENTLY_CLOSED;

        emit JobAcceptedAsComplete(jobId, clientId);
    }

    /**
    * Return the job details (Meant for FE use as a custom getter)
    * 
    * Considerations:
    * - The jobId must be valid
    */
    function getJobDetails(uint256 jobId) public view validJobId(jobId) returns(uint256, uint256, string memory, string memory, uint256, uint256, JobStatus) {
        Job memory job = jobs[jobId];
        return (job.clientId, job.acceptedFreelancerId, job.title, job.description, job.endTime, job.reward, job.status);
    }

    /**
    * Return the job application details (Meant for FE use as a custom getter)
    * 
    * Considerations:
    * - The jobId must be valid
    * - The jobId application must be valid
    */
    function getApplicationDetails(uint256 jobId, uint256 applicationId) public view validJobId(jobId) validApplicationId(jobId, applicationId) returns(uint256, string memory, bool) {
        Application memory application = jobApplications[jobId][applicationId];
        return (application.freelancerId, application.proposal, application.isAccepted);
    }

    /**
    * Return the number of applicants for a job
    * 
    * Considerations:
    * - The jobId must be valid
    */
    function getApplicationCountForJob(uint256 jobId) public view validJobId(jobId) returns(uint256) {
        return jobApplicationCounts[jobId];
    }

    /**
    * Return True if Job is completed
    * 
    * Considerations:
    * - The jobId must be valid
    */
    function isJobCompleted(uint256 _jobId) public view validJobId(_jobId) returns(bool) {
        return jobs[_jobId].status == JobStatus.COMPLETED;
    }

    /**
    * Return True if Job is closed
    * 
    * Considerations:
    * - The jobId must be valid
    */
    function isJobClosed(uint256 _jobId) public view validJobId(_jobId) returns(bool) {
        return jobs[_jobId].status == JobStatus.PERMANENTLY_CLOSED;
    }
    /**
    * Return True if Job is Ongoing --> Client has accepted Freelancer
    * 
    * Considerations:
    * - The jobId must be valid
    */
    function isJobOngoing(uint256 _jobId) public view validJobId(_jobId) returns(bool) {
        return jobs[_jobId].status == JobStatus.ONGOING;
    }

    /**
    * Checks if a given startTime and endTime unix epoch int is valid
    * 
    * Considerations:
    * - The endTime must be at least 3 days from now
    */
    function isValidEndTime(uint256 endTime) public view returns (bool) {
        return (endTime >= block.timestamp + 3 days);
    }

    // Checks if the endTime is in the future
    function isValidTime(uint256 endTime) public view returns (bool) {
        return (endTime >= block.timestamp);
    }

    function isValidJob(uint256 jobId) public view returns (bool) {
        return (jobId > 0 && jobId <= jobCount);
    }

    // These are only because state variables arre made private, remove and amend usage if this changes

    function getJobStatus(uint256 jobId) public view validJobId(jobId) returns (JobStatus) {
        return jobs[jobId].status;
    }

    function getJobClient(uint256 jobId) public view validJobId(jobId) returns (uint256) {
        return jobs[jobId].clientId;
    }

    function getJobPaymentId(uint256 jobId) public view validJobId(jobId) returns (uint256) {
        return jobs[jobId].paymentId;
    }

    function getJobFreelancer(uint256 jobId) public view validJobId(jobId) returns (uint256) {
        return jobs[jobId].acceptedFreelancerId;
    }

    // ============================================================== METHODS ============================================================= //
}
