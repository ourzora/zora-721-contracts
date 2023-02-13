// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IOperatorFilterRegistry} from "../../src/interfaces/IOperatorFilterRegistry.sol";
import {Ownable2Step} from "../../src/utils/ownable/Ownable2Step.sol";

contract OwnedSubscriptionManager is Ownable2Step {
    IOperatorFilterRegistry immutable registry =
        IOperatorFilterRegistry(0x000000000000AAeB6D7670E522A718067333cd4E);

    constructor(address _initialOwner) Ownable2Step(_initialOwner) {
        registry.register(address(this));
    }
}
