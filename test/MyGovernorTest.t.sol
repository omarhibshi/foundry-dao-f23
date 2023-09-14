// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract MyGovernorTest is Test {
    MyGovernor governor; // the governor contract
    GovToken govToken; // the token contract
    TimeLock timelock; // the timelock contract
    Box box; // the box contracta

    //
    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote pass
    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 50400; // 1 week
    //
    address[] public proposers;
    address[] public executors;

    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);
        vm.startPrank(USER);
        govToken.delegate(USER);
        //
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        //
        bytes32 propserRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();
        //
        timelock.grantRole(propserRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);

        //
        box = new Box();
        box.transferOwnership(address(timelock)); //  timelock owns the DAO (myGovernor) and vice versa
        vm.stopPrank();
    }

    function testCanUpdtaeBoxWithoutGovernanace() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdateBox() public {
        uint256 valueToStroe = 888;
        string memory description = "stroe 1 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStroe);
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // Steps to update the box contract
        // 1. propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // View the state
        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1); // update the block timestamp to the future in our fake blockchain
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        // 2. vote*
        string memory reason = "cuz blue frog is cool";

        uint8 voteWay = 1; // voting yes

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1); // update the block timestamp to the future in our fake blockchain
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. queue the TX

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1); // update the block timestamp to the future in our fake blockchain
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. execute the TX
        governor.execute(targets, values, calldatas, descriptionHash);

        assert(box.readNumber() == valueToStroe);
        console.log("Box value ", box.readNumber());
    }
}
