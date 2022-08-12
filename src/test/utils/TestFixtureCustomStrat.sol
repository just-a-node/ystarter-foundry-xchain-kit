// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";
import "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

import {VaultWrapper} from "../../VaultWrapper.sol";
import {ExtendedDSTest} from "./ExtendedDSTest.sol";
import {IVault} from "../../interfaces/IVault.sol";
import "../../interfaces/IERC4626.sol";

import {Token} from "./Token.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant vaultArtifact = "artifacts/Vault.json";

// Base fixture deploying Vault only, so a custom strategy can be tested
contract TestFixtureCustomStrat is ExtendedDSTest {
    using SafeERC20 for IERC20;

    VaultAPI public vault;
    IVault public ivault;
    IERC4626 public vaultWrapper;
    IERC20 public weth;
    IERC20 public want;

    mapping(string => address) public tokenAddrs;
    mapping(string => uint256) public tokenPrices;

    address public gov = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address public user = address(1);
    address public whale = address(2);
    address public rewards = address(3);
    address public guardian = address(4);
    address public management = address(5);
    address public strategist = address(6);
    address public keeper = address(7);

    uint256 public minFuzzAmt;
    // @dev maximum amount of want tokens deposited based on @maxDollarNotional
    uint256 public maxFuzzAmt;
    // @dev maximum dollar amount of tokens to be deposited
    uint256 public maxDollarNotional = 1_000_000;
    // @dev maximum dollar amount of tokens for single large amount
    uint256 public bigDollarNotional = 49_000_000;
    // @dev used for non-fuzz tests to test large amounts
    uint256 public bigAmount;
    // Used for integer approximation
    uint256 public constant DELTA = 10**5;

    function setUp() public virtual {
        // NOTE: skip a few seconds to avoid block.timestamp == 0
        skip(10 seconds);

        // Create test token 
        Token _token = new Token(uint8(18));
        want = IERC20(_token);

        // Create test vault that uses the ERC4626 interface
        address _vault = deployVault(
            address(want),
            gov,
            rewards,
            "testVault",
            "testVaultToken",
            guardian,
            management
        );
        ivault = IVault(_vault);
        vault = VaultAPI(_vault);
        VaultWrapper _vaultWrapper = new VaultWrapper(vault);
        vaultWrapper = IERC4626(_vaultWrapper);

        // NOTE: assume Token is priced to 1 for simplicity
        minFuzzAmt = 10**vault.decimals() / 10;
        maxFuzzAmt = uint256(maxDollarNotional) * 10**vault.decimals();

        bigAmount = uint256(bigDollarNotional) * 10**vault.decimals();

        vm.label(address(vault), "Vault");
        vm.label(address(want), "Want");
        vm.label(address(vaultWrapper), "VaultWrapper");
        vm.label(gov, "Gov");
        vm.label(user, "User");
        vm.label(whale, "Whale");
        vm.label(rewards, "Rewards");
        vm.label(guardian, "Guardian");
        vm.label(management, "Management");
        vm.label(strategist, "Strategist");
        vm.label(keeper, "Keeper");
    }

    // Deploys a vault
    function deployVault(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management
    ) public returns (address) {
        vm.prank(_gov);
        address _vaultAddress = deployCode(vaultArtifact);
        IVault _vault = IVault(_vaultAddress);

        vm.prank(_gov);
        _vault.initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        vm.prank(_gov);
        _vault.setDepositLimit(type(uint256).max);

        return address(_vault);
    }
}
