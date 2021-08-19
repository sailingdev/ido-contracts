// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IStakeToken.sol";

contract StakeToken is IStakeToken, ERC721, Ownable {
    using SafeMath for uint256;
    // Last stake token id, start from 1
    uint256 public tokenIds;
    uint256 public constant multiplierDenominator = 100;

    struct Stake {
        uint256 amount;
        uint256 multiplier;
        uint256 depositedAt;
    }
    // stake id => stake info
    mapping(uint256 => Stake) public stakes;
    // staker wallet => stake id array
    mapping(address => uint256[]) public stakerToIds;

    event StakeAmountDecreased(uint256 stakeId, uint256 decreaseAmount);

    constructor(
        string memory name_,
        string memory symbol_
    )
        ERC721(name_, symbol_)
    { }

    /**
     * @dev Get token id array owned by wallet address.
     * @param account address
     */
    function getTokenId(
        address account
    )
        public
        override
        view
        returns (uint256[] memory)
    {
        require(account != address(0), "StakeToken#getTokenId: ZERO_ADDRESS");
        return stakerToIds[account];
    }

    /**
     * @dev Check if wallet address owns any tokens.
     * @param account address
     */
    function isTokenHolder(
        address account
    )
        public
        override
        view
        returns (bool)
    {
        require(account != address(0), "StakeToken#isTokenHolder: ZERO_ADDRESS");
        return balanceOf(account) > 0;
    }

    /**
     * @dev Return stake info from `stakeId`.
     * @param stakeId uint256
     */
    function getStake(
        uint256 stakeId
    )
        public
        override
        view
        returns (uint256, uint256, uint256)
    {
        require(_exists(stakeId), "StakeToken#getStake: STAKE_NOT_FOUND");
        return (stakes[stakeId].amount, stakes[stakeId].multiplier, stakes[stakeId].depositedAt);
    }

    /**
     * @dev Returns StakeToken multiplier.
     *
     * 0 < `tokenId` <300: 120.
     * 300 <= `tokenId` <4000: 110.
     * 4000 <= `tokenId`: 100.
     */
    function _getMultiplier()
        private
        view
        returns (uint256)
    {
        if (tokenIds < 300) {
            return 120;
        } else if (300 <= tokenIds && tokenIds < 4000) {
            return 110;
        } else {
            return 100;
        }
    }

    /**
     * @dev Mint a new StakeToken.
     * @param account address of recipient.
     * @param amount mint amount.
     * @param depositedAt timestamp when stake was deposited.
     */
    function _mint(
        address account,
        uint256 amount,
        uint256 depositedAt
    )
        internal
        virtual
        returns (uint256)
    {
        require(amount > 0, "StakeToken#mint: INVALID_AMOUNT");
        tokenIds++;
        uint256 multiplier = _getMultiplier();
        super._mint(account, tokenIds);
        Stake storage newStake = stakes[tokenIds];
        newStake.amount = amount;
        newStake.multiplier = multiplier;
        newStake.depositedAt = depositedAt;
        stakerToIds[account].push(tokenIds);

        return tokenIds;
    }

    /**
     * @dev Burn stakeToken.
     * @param stakeId id of buring token.
     */
    function _burn(
        uint256 stakeId
    )
        internal
        override
    {
        require(_exists(stakeId), "StakeToken#burn: STAKE_NOT_FOUND");
        address stakeOwner = ownerOf(stakeId);
        super._burn(stakeId);
        delete stakes[stakeId];
        uint256[] storage stakeIds = stakerToIds[stakeOwner];
        for (uint256 i = 0; i < stakeIds.length; i++) {
            if (stakeIds[i] == stakeId) {
                if (i != stakeIds.length - 1) {
                    stakeIds[i] = stakeIds[stakeIds.length - 1];
                }
                stakeIds.pop();
                break;
            }
        }
    }

    /**
     * @dev Decrease stake amount.
     * If stake amount leads to be zero, the stake is burned.
     * @param stakeId id of buring token.
     * @param amount to withdraw.
     */
    function _decreaseStakeAmount(
        uint256 stakeId,
        uint256 amount
    )
        internal
        virtual
    {
        require(_exists(stakeId), "StakeToken#_decreaseStakeAmount: STAKE_NOT_FOUND");
        require(amount <= stakes[stakeId].amount, "StakeToken#_decreaseStakeAmount: INSUFFICIENT_STAKE_AMOUNT");
        if (amount == stakes[stakeId].amount) {
            _burn(stakeId);
        } else {
            stakes[stakeId].amount = stakes[stakeId].amount.sub(amount);
            emit StakeAmountDecreased(stakeId, amount);
        }
    }
}
