pragma solidity ^0.5.16;

import "./SafeMath.sol";


//contract
contract LetContract {
    
    using SafeMath for uint256;
    uint private loxRate = 1500;
    // contract default stop when created.
    bool private stopped = true;
    address private owner;
    IERC20 public loxToken;
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
    
    event Transfer(address indexed _to, uint256 _value, uint256 _blockNumber);
    event EthSettle(address indexed _buyer, uint256 _value, uint256 _blockNumber);
    event TokenSettle(address indexed _buyer, uint256 _value);
    
    /**
    * @dev Checks if the contract is not stopped; reverts if it is.
    */
    modifier isNotStopped {
        require(!stopped, 'Contract is stopped.');
        _;
    }

    /**
    * @dev Enforces the caller to be the contract's owner.
    */
    modifier isOwner {
        require(msg.sender == owner, 'Sender is not owner.');
        _;
    }
    
    /**
     * @dev Transfer eth to this contract.
     */
    function()  isNotStopped external payable  {
        // transfer number >= 0.1个eth
        require(msg.value >= 100000000000000000, "must >= 0.1 eth");
        require(msg.value <= 100000000000000000000000, "no valid, no");
        buyerList.push(Node(msg.sender,msg.value,block.number));
        emit Transfer(msg.sender,msg.value,block.number);
    }
    
    /**
     * @dev Query current activity people number.
     */
    function activityNumber() public view returns(uint) {
        return buyerList.length;
    }
    
    
     /**
     * @dev Query whether contract is stop.
     */
    function isStop() public view returns(bool) {
        return stopped;
    }
    
    /**
    * @dev Transfer erc20 token safe.
    */
    function _safeTransferFrom(
        IERC20 token,
        address sender,
        address recipient,
        uint amount
    ) private {
        bool sent = token.transferFrom(sender, recipient, amount);
        require(sent, "Token transfer failed");
    }
    
    /**
     * @dev Sum the total eth balance of activity people.
     */
    function totalActivityBalance() isOwner public view returns(uint256) {
        uint arrayLength = buyerList.length;
        uint256 totalUserBalance = 0;
        for (uint i=0; i< arrayLength; i++) {
            Node memory node = buyerList[i];
            totalUserBalance = totalUserBalance.add(node.value);
        }
        return totalUserBalance;
    }
    
    /**
     * @dev Settle user asset,reback eth and lox token.
     */  
    function settle() isOwner public payable{
        uint arrayLength = buyerList.length;
        require(arrayLength > 0, "no people to be settle");
        uint256 feeEth = 0;
        for (uint i=0; i< arrayLength; i++) {
            Node memory node = buyerList[i];
            uint256 ethValue = node.value;
            uint256 preEth = ethValue.div(100);
            uint256 rebackEth = preEth.mul(95);
            uint256 loxTokenValue = ethValue.mul(loxRate);

            uint256 dif = ethValue.sub(rebackEth);
            feeEth = feeEth.add(dif);
            
             // transfer eth
            node.buyer.transfer(rebackEth);
            
            require(
            loxToken.allowance(msg.sender, address(this)) >= loxTokenValue,
            "loxToken allowance too low"
            );
            // transfer lox
            _safeTransferFrom(loxToken, msg.sender, node.buyer, loxTokenValue);
            emit EthSettle(node.buyer,rebackEth,node.blockNumber);
            emit TokenSettle(node.buyer,loxTokenValue);
        }
        // transfer redundant eth to owner.
        msg.sender.transfer(feeEth);
        // reset array
        delete buyerList;
    }
    
    /**
    * @dev Stops / Unstops the contract.
    */
    function toggleContractStopped() isOwner public {
        stopped = !stopped;
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
