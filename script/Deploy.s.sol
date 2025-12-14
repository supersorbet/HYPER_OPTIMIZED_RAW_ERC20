// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BarryBerry} from "../src/GhostClaws.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BarryBerry token = new BarryBerry();

        console.log("BarryBerry deployed at:", address(token));

        vm.stopBroadcast();
    }
}


