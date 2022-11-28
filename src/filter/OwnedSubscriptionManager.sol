// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IOperatorFilterRegistry} from "../../src/interfaces/IOperatorFilterRegistry.sol";
import {OwnableWithConfirmation} from "../../src/utils/OwnableWithConfirmation.sol";

contract OwnedSubscriptionManager is OwnableWithConfirmation {
    IOperatorFilterRegistry immutable registry =
        IOperatorFilterRegistry(0x000000000000AAeB6D7670E522A718067333cd4E);

    constructor(address _initialOwner) OwnableWithConfirmation(_initialOwner) {
        registry.register(address(this));
    }
}
