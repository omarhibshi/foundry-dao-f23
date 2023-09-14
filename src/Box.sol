// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_number;

    event NumberChanged(uint256 number);

    function store(uint256 _newValue) public onlyOwner {
        // only the owner (the DAO) can call this function
        s_number = _newValue;
        emit NumberChanged(_newValue);
    }

    function readNumber() external view returns (uint256) {
        return s_number;
    }
}
