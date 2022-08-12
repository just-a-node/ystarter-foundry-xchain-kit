// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {TestFixtureCustomStrat} from "./utils/TestFixtureCustomStrat.sol";
import {XChainStrategy} from "../strategies/XChainStrategy.sol";
import {Token} from "./utils/Token.sol";
// import "../../script/Token.s.sol";
import "forge-std/console.sol";

contract XChainStrategyTest is TestFixtureCustomStrat {
    uint256 public domainA;
    uint256 public domainB;

    XChainStrategy public xStrategy;
    yieldStrategy public yieldStrategy;

    function setUp() public override {
        super.setUp();

        // create forks for two domains
        domainA = vm.createFork(vm.envString("GOERLI_RPC_URL"));
        domainB = vm.createFork(vm.envString("RINKEBY_RPC_URL"));

        // setup the xchain strategy under test on DomainA
        vm.selectFork(domainA);
        vm.startPrank(strategist);
        xStrategy = new XChainStrategy(address(vault));
        xStrategy.setKeeper(keeper);

        // setup the strategy that will yield returns on DomainB
        vm.selectFork(domainB);
        yieldStrategy = new yieldStrategy(address(vault));
        vm.stopPrank();


        console.log(strategy.name());

        vm.prank(gov);
        ivault.addStrategy(address(strategy), 10_000, 0, type(uint256).max, 1_000);
    }

    function testOperation() public {
        vm.selectFork(domainA);
        console.log(vm.activeFork());


    }
}
