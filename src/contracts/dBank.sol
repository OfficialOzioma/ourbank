// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Token.sol";

contract dBank {
    //assign Token contract to variable
    Token private token;

    //add mappings
    mapping(address => uint256) public depositStart;
    mapping(address => uint256) public etherBalanceOf;
    mapping(address => uint256) public collateralEther;

    mapping(address => bool) public isDeposited;
    mapping(address => bool) public isBorrowed;

    //add events
    event Deposit(address indexed user, uint256 etherAmount, uint256 timeStart);
    event Withdraw(
        address indexed user,
        uint256 etherAmount,
        uint256 depositTime,
        uint256 interest
    );
    event Borrow(
        address indexed user,
        uint256 collateralEtherAmount,
        uint256 borrowedTokenAmount
    );
    event PayOff(address indexed user, uint256 fee);

    //pass as constructor argument deployed Token contract
    constructor(Token _token) public {
        //assign token deployed contract to variable
        token = _token;
    }

    function deposit() public payable {
        //check if msg.sender didn't already deposited funds
        require(
            isDeposited[msg.sender] == false,
            "Error, deposit already active"
        );

        //check if msg.value is >= than 0.01 ETH
        require(msg.value >= 1e16, "Error, deposit must be >= 0.01 ETH");

        etherBalanceOf[msg.sender] = etherBalanceOf[msg.sender] + msg.value;
        //increase msg.sender ether deposit balance

        //start msg.sender hodling time
        depositStart[msg.sender] = depositStart[msg.sender] + block.timestamp;

        //set msg.sender deposit status to true
        isDeposited[msg.sender] = true; //activate deposit status

        //emit Deposit event
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    function withdraw() public {
        //check if msg.sender deposit status is true
        require(isDeposited[msg.sender] == true, "Error, no previous deposit");

        //assign msg.sender ether deposit balance to variable for event
        uint256 userBalance = etherBalanceOf[msg.sender]; //for event

        //check user's hodl time
        uint256 depositTime = block.timestamp - depositStart[msg.sender];

        //CALC INTEREST PER SECOND

        // 31668017 - interest(10% APY) per second for min. deposit amount (0.01 ETH), cuz:
        // 1e15(10% of 0.01 ETH) / 31577600 (seconds in 365.25 days)

        // (etherBalanceOf[msg.sender] / 1e16) - calc. how much higher interest will be (based on deposit), e.g.:
        // for min. deposit (0.01 ETH), (etherBalanceOf[msg.sender] / 1e16) = 1 (the same, 31668017/s)
        // for deposit 0.02 ETH, (etherBalanceOf[msg.sender] / 1e16) = 2 (doubled, (2*31668017)/s)

        uint256 interestPerSecond = 31668017 *
            (etherBalanceOf[msg.sender] / 1e16);

        //calc accrued interest
        uint256 interest = interestPerSecond * depositTime;

        //send eth to user
        msg.sender.transfer(userBalance); //eth back to user

        //send interest in tokens to user
        token.mint(msg.sender, interest); //interest to user

        //reset depositer data
        etherBalanceOf[msg.sender] = 0;
        depositStart[msg.sender] = 0;
        isDeposited[msg.sender] = false;

        //emit event
        emit Withdraw(msg.sender, userBalance, depositTime, interest);
    }

    // function borrow() public payable {
    //     //check if collateral is >= than 0.01 ETH
    //     //check if user doesn't have active loan
    //     //add msg.value to ether collateral
    //     //calc tokens amount to mint, 50% of msg.value
    //     //mint&send tokens to user
    //     //activate borrower's loan status
    //     //emit event
    // }

    // function payOff() public {
    //     //check if loan is active
    //     //transfer tokens from user back to the contract
    //     //calc fee
    //     //send user's collateral minus fee
    //     //reset borrower's data
    //     //emit event
    // }

    function borrow() public payable {
        require(msg.value >= 1e16, "Error, collateral must be >= 0.01 ETH");
        require(isBorrowed[msg.sender] == false, "Error, loan already taken");

        //this Ether will be locked till user payOff the loan
        collateralEther[msg.sender] = collateralEther[msg.sender] + msg.value;

        //calc tokens amount to mint, 50% of msg.value
        uint256 tokensToMint = collateralEther[msg.sender] / 2;

        //mint&send tokens to user
        token.mint(msg.sender, tokensToMint);

        //activate borrower's loan status
        isBorrowed[msg.sender] = true;

        emit Borrow(msg.sender, collateralEther[msg.sender], tokensToMint);
    }

    function payOff() public {
        require(isBorrowed[msg.sender] == true, "Error, loan not active");
        require(
            token.transferFrom(
                msg.sender,
                address(this),
                collateralEther[msg.sender] / 2
            ),
            "Error, can't receive tokens"
        ); //must approve dBank 1st

        uint256 fee = collateralEther[msg.sender] / 10; //calc 10% fee

        //send user's collateral minus fee
        msg.sender.transfer(collateralEther[msg.sender] - fee);

        //reset borrower's data
        collateralEther[msg.sender] = 0;
        isBorrowed[msg.sender] = false;

        emit PayOff(msg.sender, fee);
    }
}
