pragma solidity ^0.5.16;

import "./SafeMath.sol";


//contract
contract LetContract {
    
    using SafeMath for uint256;
    address private loxContractAddress;
    Node[] private buyerList;
    
    struct Node {
        address payable buyer;
        uint256 value;
        uint blockNumber;
    }
    
    constructor(address loxContractAddress) public {
        // Sets the contract's owner as the address that deployed the contract.
        owner = msg.sender;
        loxToken = IERC20(loxContractAddress);
    }
    
    //TODO::
}    


//external interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
