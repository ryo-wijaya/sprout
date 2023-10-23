pragma solidity ^0.5.0;
import "./User.sol";
import "./NativeToken.sol";

contract JobListing {
    
    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //

    enum JobStatus {
        CLOSED,
        OPEN,
        ONGOING,
        COMPLETED
    }

    struct Job {
        uint256 clientId;
        uint256 acceptedFreelancerId; // This should be cleared after a job is done
        string title;
        string description;
        string startDate;
        string endDate;
        uint256 reward;
        JobStatus status;
    }

    struct Application {
        uint256 freelancerId;
        string proposal;
        bool isAccepted;
    }

    User userContract;
    NativeToken nativeTokenContract;
    uint256 private jobCount = 0;
    mapping(uint256 => Job) jobs; // Get job details here by jobId
    // This is a mapping of job -> applications -> application
    // jobApplications[jobId] -> All the applications for that job
    // jobApplications[jobId][applicationId] -> A specific application for that job
    mapping(uint256 => mapping(uint256 => Application)) private jobApplications;
    // This is to keep track of the number of applications for a job
    mapping(uint256 => uint256) private jobApplicationCounts;

    constructor(address _userAddress, address _nativeTokenAddress) public {
        userContract = User(_userAddress);
        nativeTokenContract = NativeToken(_nativeTokenAddress);
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
        require(userContract.getAddressFromUserId(userId) == msg.sender, "This userId does not correspond to yourself.");
        _;
    }

    modifier validJobId(uint256 jobId) {
        require(jobId > 0 && jobId <= jobCount, "Invalid Job ID");
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
    * - You need to have enough tokens to pay the reward
    */
    function createJob(uint256 clientId, string memory title, string memory description, string memory startDate, string memory endDate, uint256 reward) public userIdMatches(clientId) {
        require(userContract.isClient(clientId), "Only clients can create jobs.");
        require(nativeTokenContract.checkCredit(msg.sender) >= reward, "Client does not have enough tokens for reward.");
        jobCount++;
        Job memory newJob = Job({
            clientId: clientId,
            acceptedFreelancerId: 0, // This basically means null, userIds start from 1
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
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
    * - Only the client who made the job post can edit it
    * - Only a job that has no applications can be edited
    * - Do a check for the job to be not ongoing (The above condition makes this redundant but this is just for safety)
    */
    function updateJob(uint256 clientId, uint256 jobId, string memory title, string memory description, string memory startDate, string memory endDate, uint256 reward) public userIdMatches(clientId) validJobId(jobId) {
        Job storage job = jobs[jobId];

        require(job.clientId == clientId, "Only the client who made the job post can edit it.");
        require(job.status != JobStatus.ONGOING && job.status != JobStatus.COMPLETED, "Job is ONGOING or COMPLETED and cannot be edited.");

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
        job.startDate = startDate;
        job.endDate = endDate;
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
    * - Once a job is closed, no more applications should be able to be made
    * - Once a job is closed, all applications tied to it are wiped
    * - A job that is ongoing cannot be closed
    * - Only the client who posted the job can close it
    */
    function closeJob(uint256 clientId, uint256 jobId) public validJobId(jobId) userIdMatches(clientId) {
        require(jobs[jobId].clientId == clientId, "Only the client who posted the job can close it.");
        require(jobs[jobId].status == JobStatus.OPEN, "This job is currently ONGOING and cannot be closed.");

        jobs[jobId].status = JobStatus.CLOSED;

        // Wipe all applications for this job
        for (uint256 i = 1; i <= jobApplicationCounts[jobId]; i++) {
            delete jobApplications[jobId][i];
        }
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
    */
    function reopenJob(uint256 clientId, uint256 jobId) public validJobId(jobId) userIdMatches(clientId) {
        require(jobs[jobId].clientId == clientId, "Only the client who posted the job can re-open it.");
        require(jobs[jobId].status == JobStatus.CLOSED, "This job is not currently CLOSED.");

        jobs[jobId].status = JobStatus.OPEN;

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

        Application memory newApplication = Application({
            freelancerId: freelancerId, 
            proposal: proposal,
            isAccepted: false
        });

        jobApplicationCounts[jobId]++;
        uint256 applicationIdForJob = jobApplicationCounts[jobId];
        jobApplications[jobId][applicationIdForJob] = newApplication;

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
    */
    function acceptApplication(uint256 clientId, uint256 jobId, uint256 applicationId) public userIdMatches(clientId) validJobId(jobId) validApplicationId(jobId, applicationId) {
        Job storage job = jobs[jobId];
        Application storage application = jobApplications[jobId][applicationId];

        require(job.status == JobStatus.OPEN, "The job is not open.");
        require(job.clientId == clientId, "You are not the client who posted this job.");
        require(!userContract.haveSameAddress(application.freelancerId, job.clientId), "You are both the freelancer and the client, you cannot accept your own job application");
        
        application.isAccepted = true;
        job.status = JobStatus.ONGOING;
        job.acceptedFreelancerId = application.freelancerId;

        // TODO: Send reward to escrow contract here

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
        require(job.acceptedFreelancerId == freelancerId, "You are not the accepted freelancer for this job.");
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

        require(job.clientId == clientId, "You are not the client who posted this job.");
        require(job.status == JobStatus.COMPLETED, "This job has not been marked as completed by the freelancer.");

        // TODO: Instruct escrow contract to release payment

        // Clear all associated applications with this job and close it
        for (uint256 i = 1; i <= jobApplicationCounts[jobId]; i++) {
            delete jobApplications[jobId][i];
        }

        jobApplicationCounts[jobId] = 0;
        job.acceptedFreelancerId = 0;
        job.status = JobStatus.CLOSED;

        emit JobAcceptedAsComplete(jobId, clientId);
    }

    /**
    * Return the job details (Meant for FE use as a custom getter)
    * 
    * Considerations:
    * - The jobId must be valid
    */
    function getJobDetails(uint256 jobId) public view validJobId(jobId) returns(uint256, uint256, string memory, string memory, uint256, JobStatus) {
        Job memory job = jobs[jobId];
        return (job.clientId, job.acceptedFreelancerId, job.title, job.description, job.reward, job.status);
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
    // ============================================================== METHODS ============================================================= //
}
