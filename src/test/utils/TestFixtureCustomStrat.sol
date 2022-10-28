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
// string constant vaultArtifact = "out/YieldVault.sol/YieldVault.json";

// Base fixture deploying ERC4626 vaults on two domains
contract TestFixtureCustomStrat is ExtendedDSTest {
    using SafeERC20 for IERC20;

    uint256 public domainA;
    uint256 public domainB;

    uint32 public originDomain = 1735353714;
    uint32 public destinationDomain = 1735356532;
    address public originConnext = 0x8664bE4C5C12c718838b5dCd8748B66F3A0f6A18;
    address public destinationConnext = 0xB7CF5324641bD9F82903504c56c9DE2193B4822F;

    // Adheres to the vault interface of BaseStrategy
    VaultAPI public vaultA;
    VaultAPI public vaultB;
    
    // ERC4626-compatible vault
    IERC4626 public vaultWrapperA;
    IERC4626 public vaultWrapperB;

    // Want token for the vault
    IERC20 public wantA;
    IERC20 public wantB;

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

        // ============ Forks ============

        domainA = vm.createFork(vm.envString("GOERLI_RPC_URL"));
        domainB = vm.createFork(vm.envString("OPT_GOERLI_RPC_URL"));

        // ============ Domain A: Vault ============
        // Set up the vault that uses the ERC4626 interface on the origin domain.

        vm.selectFork(domainA);

        Token _tokenA = new Token(uint8(18));
        wantA = IERC20(_tokenA);

        address _vaultA = deployVault(
            address(wantA),
            gov,
            rewards,
            "testVaultA",
            "testVaultTokenA",
            guardian,
            management
        );
        console.log("address of vaultA:", address(_vaultA));

        vaultA = VaultAPI(_vaultA);
        VaultWrapper _vaultWrapperA = new VaultWrapper(vaultA);
        vaultWrapperA = IERC4626(_vaultWrapperA);

        // ============ Domain B: Vault ============
        // Set up the xchain vault that uses the ERC4626 interface on the destination domain.

        vm.selectFork(domainB);

        Token _tokenB = new Token(uint8(18));
        wantB = IERC20(_tokenB);

        address _vaultB = deployVyperVault(
            address(wantB),
            gov,
            rewards,
            "testVaultB",
            "testVaultTokenB",
            guardian,
            management
        );
        console.log("address of vaultB:", address(_vaultB));
        vm.makePersistent(address(vaultB));
        vaultB = VaultAPI(_vaultB);
        vm.selectFork(domainA);
        VaultWrapper _vaultWrapperB = new VaultWrapper(vaultB);
        // vaultWrapperB = IERC4626(_vaultWrapperB);

        // ============ Misc ============

        // NOTE: assume Token is priced to 1 for simplicity
        // minFuzzAmt = 10**vaultB.decimals() / 10;
        // maxFuzzAmt = uint256(maxDollarNotional) * 10**vaultB.decimals();
        // bigAmount = uint256(bigDollarNotional) * 10**vaultB.decimals();

        // // Make these persistent so that they can be accessed from other forks
        // vm.makePersistent(gov);
        // vm.makePersistent(user);
        // vm.makePersistent(whale);
        // vm.makePersistent(rewards);
        // vm.makePersistent(guardian);
        // vm.makePersistent(management);
        // vm.makePersistent(strategist);
        // vm.makePersistent(keeper);
        // vm.makePersistent(address(wantA));
        // vm.makePersistent(address(wantB));
        // vm.makePersistent(address(vaultA));
        // vm.makePersistent(address(vaultB));
        // vm.makePersistent(address(vaultWrapperA));
        // vm.makePersistent(address(vaultWrapperB));

        // vm.label(gov, "Gov");
        // vm.label(user, "User");
        // vm.label(whale, "Whale");
        // vm.label(rewards, "Rewards");
        // vm.label(guardian, "Guardian");
        // vm.label(management, "Management");
        // vm.label(strategist, "Strategist");
        // vm.label(keeper, "Keeper");
        // vm.label(address(vaultA), "VaultA");
        // vm.label(address(vaultB), "VaultB");
        // vm.label(address(wantA), "WantA");
        // vm.label(address(wantB), "WantB");
        // // vm.label(address(vaultWrapperA), "VaultWrapperA");
        // vm.label(address(vaultWrapperB), "VaultWrapperB");
    }

    // Deploys a vault from the artifact
    function deployVault(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management
    ) public returns (address) {
        vm.startPrank(_gov);

        address _vaultAddress = deployCode(vaultArtifact);
        IVault _vault = IVault(_vaultAddress);

        _vault.initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        _vault.setDepositLimit(type(uint256).max);

        vm.stopPrank();

        return address(_vault);
    }

    // Deploys a vault from the Vyper contract
    function deployVyperVault(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management
    ) public returns (address) {
        ///@notice create a list of strings with the commands necessary to compile Vyper contracts
        string[] memory cmds = new string[](2);
        cmds[0] = "vyper";
        cmds[1] = "../../vyper_contracts/Vault.vy";

        ///@notice compile the Vyper contract and return the bytecode
        bytes memory bytecode = vm.ffi(cmds);

        // //add args to the deployment bytecode
        // bytes memory bytecode = abi.encodePacked(_bytecode, args);

        ///@notice deploy the bytecode with the create instruction
        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        ///@notice check that the deployment was successful
        require(
            deployedAddress != address(0),
            "VyperDeployer could not deploy contract"
        );

        IVault(deployedAddress).initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        ///@notice return the address that the contract was deployed to
        return deployedAddress;
    }
}
