pragma solidity ^0.5.0;
import "./User.sol";

contract JobListing {
    
    struct Job {
        uint256 userId;
        string title;
        string description;
        uint256 reward;
        bool isOpen;
    }

    struct Application {
        uint256 freelancerId;
        string proposal;
        bool isAccepted;
    }

    User public userContract;
    uint256 public jobCount = 0;
    mapping(uint256 => Job) public jobs; // Get job details here by jobId

    uint256 public applicationCount = 0;
    mapping(uint256 => mapping(uint256 => Application)) public jobApplications; // jobId -> applicationId -> Application

    // jobApplications[jobId] -> All the applications for that job
    // jobApplications[jobId][applicationId] -> A specific application for that job

    event JobCreated(uint256 jobId, string title);
    event JobClosed(uint256 jobId, string title);
    event ApplicationCreated(uint256 jobId, uint256 applicationId);

    constructor(address _userAddress) public {
        userContract = User(_userAddress);
    }

    function createJob(uint256 userId, string memory title, string memory description, uint256 reward) public {
        require(userContract.isClient(userId), "Only clients can create jobs.");

        jobCount++;
        Job memory newJob = Job({
            userId: userId,
            title: title,
            description: description,
            reward: reward,
            isOpen: true
        });
        jobs[jobCount] = newJob;
        emit JobCreated(jobCount, title);
    }

    // Can't returned named structures in solidity, use the public `jobs` reference instead to be clear
    function getJobDetails(uint256 jobId) public view returns(uint256, string memory, string memory, uint256, bool) {
        Job memory job = jobs[jobId];
        return (job.userId, job.title, job.description, job.reward, job.isOpen);
    }

    function closeJob(uint256 userId, uint256 jobId) public {
        require(jobs[jobId].userId == userId, "Only the client who posted the job can close it.");
        jobs[jobId].isOpen = false;
        emit JobClosed(jobId, jobs[jobId].title);
    }

    function applyForJob(uint256 userId, uint256 jobId, string memory proposal) public {
        require(jobs[jobId].isOpen, "Job is not open for applications");
        // put check here so only freelancers can apply
        // put check here such that once you apply you cannot reapply

        applicationCount++;
        Application memory newApplication = Application({
            freelancerId: userId, 
            proposal: proposal,
            isAccepted: false
        });

        jobApplications[jobId][applicationCount] = newApplication;
        emit ApplicationCreated(jobId, applicationCount);
    }

    function acceptApplication(uint256 applicationId) public {
        // verify that only the client who posted the job can accept the application
    }
}
