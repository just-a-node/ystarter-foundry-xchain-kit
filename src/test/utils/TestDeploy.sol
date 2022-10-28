// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "./VyperDeployer.sol";

import {ExtendedDSTest} from "./ExtendedDSTest.sol";
import {IVault} from "../../interfaces/IVault.sol";

contract TestDeploy is ExtendedDSTest {
    ///@notice create a new instance of VyperDeployer
    VyperDeployer public vyperDeployer = new VyperDeployer();
    IVault vault1;
    IVault vault2;


    function setUp() public {
        // vault = vyperDeployer.deployContract("Vault", abi.encode(1234));
        vault1 = IVault(vyperDeployer.deployContract("Vault"));
        vault2 = IVault(vyperDeployer.deployContract("Vault"));

    }

    function testGet() public {
        assertEq(address(vault1), address(vault2));
    }
}
