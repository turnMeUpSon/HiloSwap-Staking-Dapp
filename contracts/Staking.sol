// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Staking {
    address public owner;

    uint public currentTokenId = 1;

    struct Token {
        uint tokenId;
        string name;
        string symbol;
        address tokenAddress;
        uint usdPrice;
        uint ethPrice;
        uint apy;
    }

    struct Position {
        uint positionId;
        address walletAddress;
        string name;
        string symbol;
        uint createdDate;
        uint apy;
        uint tokenQuantity;
        uint usdValue;
        uint ethValue;
        bool isOpen;
    }

    uint public ethUsdPrice;

    // Mapping of tokens(list of token symbols => struct Token)
    string[] public tokenSymbols;
    mapping(string => Token) public tokens;

    // Mapping of positions(curr postionId => struct Position)
    uint public currentPositionId = 1;
    mapping(uint => Position) public positions;

    // Mapping of position Ids(address token => list of position ids)
    mapping(address => uint[]) public positionIdsByAddress;

    // Mapping of staked tokens(string symbol of token => quantity of tokens)
    mapping(string => uint) public stakedTokens;

    constructor(uint currentEthUsdPrice) payable {
        ethUsdPrice = currentEthUsdPrice;
        owner = msg.sender;
    }

    function addToken(
        string calldata name,
        string calldata symbol,
        address tokenAddress,
        uint usdPrice,
        uint apy
    ) external onlyOwner {
        tokenSymbols.push(symbol);

        tokens[symbol] = Token(
            currentTokenId,
            name,
            symbol,
            tokenAddress,
            usdPrice,
            usdPrice / ethPrice,
            apy
        );

        currentTokenId += 1;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner can call this function");
        _;
    }

    function getTokenSymbols() public view returns (string[] memory) {
        return tokenSymbols;
    }

    function getToken(
        string calldata tokenSymbol
    ) public view returns (Token memory) {
        return tokens[tokenSymbol];
    }

    function stakeToken(string calldata symbol, uint tokenQuantity) external {
        require(tokens[symbol].tokenId != 0, "This token can't be staked");

        IERC20(tokens[symbol].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokenQuantity
        );

        positions[currentPositionId] = Position(
            currentPositionId,
            msg.sender,
            tokens[symbol].name,
            symbol,
            block.timestamp,
            tokens[symbol].apy,
            tokenQuantity,
            tokens[symbol].usdPrice * tokenQuantity,
            (tokens[symbol].usdPrice * tokenQuantity) / ethUsdPrice,
            true
        );

        positionIdsByAddress[msg.sener].push(currentPositionId);
        currentPositionId += 1;
        stakedTokens[symbol] += tokenQuantity;
    }

    function getPositionIdsForAddress() external view returns (uint[] memory) {
        return positionIdsByAddress[msg.sender];
    }

    function getPositionById(
        uint positionId
    ) external view returns (Position memory) {
        return positions[positionId];
    }

    function calculateInterest(
        uint apy,
        uint value,
        uint numberDays
    ) public pure returns (uint) {
        return (apy * value * numberDays) / 1000 / 365;
    }

    function closePosition(uint positionId) external {
        require(
            positions[positionId].walletAddress == msg.sender,
            "Not the owner of this position"
        );
        require(
            positions[positionId].isOpen == true,
            "Position already closed"
        );

        positions[positionId].isOpen = false;

        IERC20(tokens[positions[positionId].symbol].tokenAddress).transfer(
            msg.sender,
            positions[positionId].tokenQuantity
        );

        uint numberDays = calculateNumberDays(
            positions[positionId].createdDate
        );

        uint weiAmount = calculateInterest(
            positions[positionId].apy,
            positions[positionId].ethValue,
            numberDays
        );

        payable(msg.sender).call{value: weiAmount}("");
    }

    function calculateNumberDays(uint createdDate) public view returns (uint) {
        return (block.timestamp - createdDate) / 60 / 60 / 24;
    }

    function modifyCreatedDate(
        uint positionId,
        uint newCreatedDate
    ) external onlyOwner {
        positions[positionId].createdDate = newCreatedDate;
    }
}
