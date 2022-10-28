// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IERC4626.sol";

import {IConnextHandler} from "nxtp/core/connext/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/core/connext/interfaces/IExecutor.sol";
import {ExtendedDSTest} from "../test/utils/ExtendedDSTest.sol";

/********************
 *
 * Example of a custom vault that handles cross-chain deposits.
 *
 ********************/

contract YieldVault is Ownable, ExtendedDSTest {
    // Connext contracts
    IConnextHandler public immutable connext;
    IExecutor public immutable executor;

    // Nomad Domain IDs 
    uint32 public immutable originDomain;
    uint32 public immutable destinationDomain;

    // Contracts on origin domain
    address public originVault;
    address public originStrategy;

    IERC4626 public immutable vault;
    IERC20 public immutable token;
    mapping(address => uint256) public tokenBalances;
    mapping(address => uint256) public shareBalances;
    mapping(address => address) public donatorToReceiver;
    mapping(address => mapping(address => bool)) public receiverToDonator;
    uint256 public dust = 1e16;

    // A modifier for authenticated function calls.
    // Note: This is an important security consideration. If your target
    //       contract function is meant to be authenticated, it must check
    //       that the originating call is from the correct domain and contract.
    //       Also, check that the msg.sender is the Connext Executor address.
    modifier onlyExecutor() {
        require(
        IExecutor(msg.sender).originSender() == originStrategy &&
            IExecutor(msg.sender).origin() == originDomain &&
            msg.sender == address(executor),
        "Expected origin contract on origin domain called by Executor"
        );
        _;
    }

    constructor(
        address _vault,
        uint32 _originDomain,
        uint32 _destinationDomain,
        IConnextHandler _connext,
        address _originVault, 
        address _originStrategy 
    ) {
        vault = IERC4626(_vault);
        token = IERC20(vault.asset());
        token.approve(address(vault), type(uint256).max);

        originDomain = _originDomain;
        destinationDomain = _destinationDomain;
        connext = _connext;
        executor = _connext.executor();
        originVault = _originVault;
        originStrategy = _originStrategy;
    }

    // handler for xcall
    function xDeposit(uint256 amount) external onlyExecutor {
        vault.deposit(amount, address(this));
        // balances accounting
    }

}
