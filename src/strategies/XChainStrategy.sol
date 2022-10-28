// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseStrategyInitializable, StrategyParams, VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";
import {IConnextHandler} from "nxtp/core/connext/interfaces/IConnextHandler.sol";
import {ICallback} from "nxtp/core/promise/interfaces/ICallback.sol";
import {CallParams, XCallArgs} from "nxtp/core/connext/libraries/LibConnextStorage.sol";
import {ExtendedDSTest} from "../test/utils/ExtendedDSTest.sol";

/********************
 *
 * Example of a cross-chain strategy.
 *
 * @dev to simulate gains just transfer/airdrop tokens to this contract and call harvest
 * @dev for instructive purposes we avoid using unchecked block in some spots
 *
 ********************/

contract XChainStrategy is BaseStrategyInitializable, ExtendedDSTest {
    // Connext contracts
    IConnextHandler public immutable connext;
    // address public immutable promiseRouter;

    // Nomad Domain IDs
    uint32 public immutable originDomain;
    uint32 public immutable destinationDomain;

    // Contracts on destination domain
    address public destinationVault;
    address public destinationStrategy;

    // Some token that needs to be protected for some reason
    // Initialize this to some fake address, because we're just using it
    // to test `BaseStrategy.protectedTokens()`
    address public constant PROTECTED_TOKEN = address(0xbad);

    constructor(
        address _vault,
        uint32 _originDomain,
        uint32 _destinationDomain,
        IConnextHandler _connext,
        address _destinationVault, 
        address _destinationStrategy 
    ) BaseStrategyInitializable(_vault) {
        originDomain = _originDomain;
        destinationDomain = _destinationDomain;
        connext = _connext;
        destinationVault = _destinationVault;
        destinationStrategy = _destinationStrategy;
    }

    function name() external pure override returns (string memory) {
        return string(abi.encodePacked("XChainStrategy ", apiVersion()));
    }

    // NOTE: This is a test-only function to simulate losses
    function _takeFunds(uint256 amount) public {
        SafeERC20.safeTransfer(want, msg.sender, amount);
    }

    // NOTE: This is a test-only function to simulate a wrong want token
    function _setWant(IERC20 _want) public {
        want = _want;
    }

    function ethToWant(uint256 amtInWei)
        public
        pure
        override
        returns (uint256)
    {
        return amtInWei; // 1:1 conversion for testing
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return want.balanceOf(address(this));
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // During testing, send this contract some tokens to simulate "Rewards"
        uint256 totalAssets = estimatedTotalAssets();
        uint256 totalDebt = vault.strategies(address(this)).totalDebt;
        if (totalAssets > _debtOutstanding) {
            _debtPayment = _debtOutstanding;
            totalAssets = totalAssets - _debtOutstanding;
        } else {
            _debtPayment = totalAssets;
            totalAssets = 0;
        }
        totalDebt = totalDebt - _debtPayment;

        if (totalAssets > totalDebt) {
            _profit = totalAssets - totalDebt;
        } else {
            _loss = totalDebt - totalAssets;
        }

        console.log("prepareReturn _profit", _profit);
        console.log("prepareReturn _loss", _loss);
        console.log("prepareReturn _debtPayment", _debtPayment);
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        console.log("in adjustposition, debtOutstanding:", _debtOutstanding);
        uint256 balanceOfWant = want.balanceOf(address(this));
        console.log("balanceOfWant", balanceOfWant);

        // xDeposit(destinationVault, originDomain, destinationDomain, balanceOfWant);
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        uint256 totalDebt = vault.strategies(address(this)).totalDebt;
        uint256 totalAssets = want.balanceOf(address(this));
        if (_amountNeeded > totalAssets) {
            _liquidatedAmount = totalAssets;
            _loss = _amountNeeded - totalAssets;
        } else {
            // NOTE: Just in case something was stolen from this contract
            if (totalDebt > totalAssets) {
                _loss = totalDebt - totalAssets;
                if (_loss > _amountNeeded) _loss = _amountNeeded;
            }
            _liquidatedAmount = _amountNeeded;
        }
    }

    function prepareMigration(address _newStrategy) internal override {
        // do nothing
    }

    function protectedTokens()
        internal
        pure
        override
        returns (address[] memory)
    {
        address[] memory protected = new address[](1);
        protected[0] = PROTECTED_TOKEN;
        return protected;
    }

    function liquidateAllPositions()
        internal
        override
        returns (uint256 amountFreed)
    {
        uint256 totalAssets = want.balanceOf(address(this));
        amountFreed = totalAssets;
    }

    /**
     * @notice
     *  Execute a cross-chain deposit into the yield-generating domain's vault.
     * @dev
     *  This call and `harvestTrigger()` should never return `true` at the same
     *  time.
     */
    // function xDeposit(
    //     address vault, 
    //     uint32 originDomain, 
    //     uint32 destinationDomain, 
    //     uint256 amount
    // ) internal {
    //     bytes4 selector = bytes4(keccak256("deposit(uint256,address)"));
    //     bytes memory callData = abi.encodeWithSelector(selector, amount);

    //     CallParams memory callParams = CallParams({
    //         to: vault,
    //         callData: callData,
    //         originDomain: originDomain,
    //         destinationDomain: destinationDomain,
    //         agent: msg.sender, // address allowed to transaction on destination side in addition to relayers
    //         recovery: msg.sender, // fallback address to send funds to if execution fails on destination side
    //         forceSlow: false, // option to force Nomad slow path (~30 mins) instead of paying 0.05% fee
    //         receiveLocal: false, // option to receive the local Nomad-flavored asset instead of the adopted asset
    //         // callback: address(this), // this contract implements the callback
    //         callback: address(0), // no callback
    //         callbackFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
    //         relayerFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
    //         slippageTol: 9995 // tolerate .05% slippage
    //     });

    //     XCallArgs memory xcallArgs = XCallArgs({
    //         params: callParams,
    //         transactingAssetId: address(want),
    //         amount: amount
    //     });

    //     connext.xcall(xcallArgs);
    // }

    /**
     * Callback function required for contracts implementing the ICallback interface.
     @dev This function is called to handle return data from the destination domain.
     */ 
    // function callback(
    //     bytes32 transferId,
    //     bool success,
    //     bytes memory data
    // ) external onlyPromiseRouter {
    //     uint256 newValue = abi.decode(data, (uint256));
    //     emit CallbackCalled(transferId, success, newValue);
    // }
}
