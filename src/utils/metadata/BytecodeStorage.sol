// SPDX-License-Identifier: LGPL-3.0-only
// Created By: Art Blocks Inc.

pragma solidity ^0.8.0;

/**
 * @title Art Blocks Script Storage Library
 * @notice Utilize contract bytecode as persistant storage for large chunks of script string data.
 *
 * @author Art Blocks Inc.
 * @author Modified from 0xSequence (https://github.com/0xsequence/sstore2/blob/master/contracts/SSTORE2.sol)
 * @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SSTORE2.sol)
 *
 * @dev Compared to the above two rerferenced libraries, this contracts-as-storage implementation makes a few
 *      notably different design decisions:
 *      - uses the `string` data type for input/output on reads, rather than speaking in bytes directly
 *      - exposes "delete" functionality, allowing no-longer-used storage to be purged from chain state
 *      - stores the "writer" address (library user) in the deployed contract bytes, which is useful for both:
 *         a) providing necessary information for safe deletion; and
 *         b) allowing this to be introspected on-chain
 *      Also, given that much of this library is written in assembly, this library makes use of a slightly
 *      different convention (when compared to the rest of the Art Blocks smart contract repo) around
 *      pre-defining return values in some cases in order to simplify need to directly memory manage these
 *      return values.
 */
library BytecodeStorage {
    //---------------------------------------------------------------------------------------------------------------//
    // Starting Index | Size | Ending Index | Description                                                            //
    //---------------------------------------------------------------------------------------------------------------//
    // 0              | N/A  | 0            |                                                                        //
    // 0              | 72   | 72           | the bytes of the gated-cleanup-logic allowing for `selfdestruct`ion    //
    // 72             | 32   | 104          | the 32 bytes for storing the deploying contract's (0-padded) address   //
    //---------------------------------------------------------------------------------------------------------------//
    // Define the offset for where the "logic bytes" end, and the "data bytes" begin. Note that this is a manually
    // calculated value, and must be updated if the above table is changed. It is expected that tests will fail
    // loudly if these values are not updated in-step with eachother.
    uint256 internal constant DATA_OFFSET = 104;
    uint256 internal constant ADDRESS_OFFSET = 72;

    /*//////////////////////////////////////////////////////////////
                           WRITE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Write a string to contract bytecode
     * @param _data string to be written to contract. No input validation is performed on this parameter.
     * @return address_ address of deployed contract with bytecode containing concat(gated-cleanup-logic, address, data)
     */
    function writeToBytecode(
        string memory _data
    ) internal returns (address address_) {
        // prefix bytecode with
        bytes memory creationCode = abi.encodePacked(
            //---------------------------------------------------------------------------------------------------------------//
            // Opcode  | Opcode + Arguments  | Description  | Stack View                                                     //
            //---------------------------------------------------------------------------------------------------------------//
            // (0) creation code returns all code in the contract except for the first 11 (0B in hex) bytes, as these 11
            //     bytes are the creation code itself which we do not want to store in the deployed storage contract result
            //---------------------------------------------------------------------------------------------------------------//
            // 0x60    |  0x60_0B            | PUSH1 11     | codeOffset                                                     //
            // 0x59    |  0x59               | MSIZE        | 0 codeOffset                                                   //
            // 0x81    |  0x81               | DUP2         | codeOffset 0 codeOffset                                        //
            // 0x38    |  0x38               | CODESIZE     | codeSize codeOffset 0 codeOffset                               //
            // 0x03    |  0x03               | SUB          | (codeSize - codeOffset) 0 codeOffset                           //
            // 0x80    |  0x80               | DUP          | (codeSize - codeOffset) (codeSize - codeOffset) 0 codeOffset   //
            // 0x92    |  0x92               | SWAP3        | codeOffset (codeSize - codeOffset) 0 (codeSize - codeOffset)   //
            // 0x59    |  0x59               | MSIZE        | 0 codeOffset (codeSize - codeOffset) 0 (codeSize - codeOffset) //
            // 0x39    |  0x39               | CODECOPY     | 0 (codeSize - codeOffset)                                      //
            // 0xf3    |  0xf3               | RETURN       |                                                                //
            //---------------------------------------------------------------------------------------------------------------//
            // (11 bytes)
            hex"60_0B_59_81_38_03_80_92_59_39_F3",
            //---------------------------------------------------------------------------------------------------------------//
            // Opcode  | Opcode + Arguments  | Description  | Stack View                                                     //
            //---------------------------------------------------------------------------------------------------------------//
            // (1a) conditional logic for determing purge-gate (only the bytecode contract deployer can `selfdestruct`)
            //---------------------------------------------------------------------------------------------------------------//
            // 0x60    |  0x60_20            | PUSH1 32           | 32                                                       //
            // 0x60    |  0x60_48            | PUSH1 72 (*)       | contractOffset 32                                        //
            // 0x60    |  0x60_00            | PUSH1 0            | 0 contractOffset 32                                      //
            // 0x39    |  0x39               | CODECOPY           |                                                          //
            // 0x60    |  0x60_00            | PUSH1 0            | 0                                                        //
            // 0x51    |  0x51               | MLOAD              | byteDeployerAddress                                      //
            // 0x33    |  0x33               | CALLER             | msg.sender byteDeployerAddress                           //
            // 0x14    |  0x14               | EQ                 | (msg.sender == byteDeployerAddress)                      //
            //---------------------------------------------------------------------------------------------------------------//
            // (12 bytes: 0-11 in deployed contract)
            hex"60_20_60_48_60_00_39_60_00_51_33_14",
            //---------------------------------------------------------------------------------------------------------------//
            // (1b) load up the destination jump address for `(2a) calldata length check` logic, jump or raise `invalid` op-code
            //---------------------------------------------------------------------------------------------------------------//
            // 0x60    |  0x60_10            | PUSH1 16 (^)       | jumpDestination (msg.sender == byteDeployerAddress)      //
            // 0x57    |  0x57               | JUMPI              |                                                          //
            // 0xFE    |  0xFE               | INVALID            |                                                          //
            //---------------------------------------------------------------------------------------------------------------//
            // (4 bytes: 12-15 in deployed contract)
            hex"60_10_57_FE",
            //---------------------------------------------------------------------------------------------------------------//
            // (2a) conditional logic for determing purge-gate (only if calldata length is 1 byte)
            //---------------------------------------------------------------------------------------------------------------//
            // 0x5B    |  0x5B               | JUMPDEST (16)      |                                                          //
            // 0x60    |  0x60_01            | PUSH1 1            | 1                                                        //
            // 0x36    |  0x36               | CALLDATASIZE       | calldataSize 1                                           //
            // 0x14    |  0x14               | EQ                 | (calldataSize == 1)                                      //
            //---------------------------------------------------------------------------------------------------------------//
            // (5 bytes: 16-20 in deployed contract)
            hex"5B_60_01_36_14",
            //---------------------------------------------------------------------------------------------------------------//
            // (2b) load up the destination jump address for `(3a) calldata value check` logic, jump or raise `invalid` op-code
            //---------------------------------------------------------------------------------------------------------------//
            // 0x60    |  0x60_19            | PUSH1 25 (^)       | jumpDestination (calldataSize == 1)                      //
            // 0x57    |  0x57               | JUMPI              |                                                          //
            // 0xFE    |  0xFE               | INVALID            |                                                          //
            //---------------------------------------------------------------------------------------------------------------//
            // (4 bytes: 21-24 in deployed contract)
            hex"60_19_57_FE",
            //---------------------------------------------------------------------------------------------------------------//
            // (3a) conditional logic for determing purge-gate (only if calldata is `0xFF`)
            //---------------------------------------------------------------------------------------------------------------//
            // 0x5B    |  0x5B               | JUMPDEST (25)      |                                                          //
            // 0x60    |  0x60_00            | PUSH1 0            | 0                                                        //
            // 0x35    |  0x35               | CALLDATALOAD       | calldata                                                 //
            // 0x7F    |  0x7F_FF_00_..._00  | PUSH32 0xFF00...00 | 0xFF0...00 calldata                                      //
            // 0x14    |  0x14               | EQ                 | (0xFF00...00 == calldata)                                //
            //---------------------------------------------------------------------------------------------------------------//
            // (4 bytes: 25-28 in deployed contract)
            hex"5B_60_00_35",
            // (33 bytes: 29-61 in deployed contract)
            hex"7F_FF_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00",
            // (1 byte: 62 in deployed contract)
            hex"14",
            //---------------------------------------------------------------------------------------------------------------//
            // (3b) load up the destination jump address for actual purging (4), jump or raise `invalid` op-code
            //---------------------------------------------------------------------------------------------------------------//
            // 0x60    |  0x60_43            | PUSH1 67 (^)       | jumpDestination (0xFF00...00 == calldata)                //
            // 0x57    |  0x57               | JUMPI              |                                                          //
            // 0xFE    |  0xFE               | INVALID            |                                                          //
            //---------------------------------------------------------------------------------------------------------------//
            // (4 bytes: 63-66 in deployed contract)
            hex"60_43_57_FE",
            //---------------------------------------------------------------------------------------------------------------//
            // (4) perform actual purging
            //---------------------------------------------------------------------------------------------------------------//
            // 0x5B    |  0x5B               | JUMPDEST (67)      |                                                          //
            // 0x60    |  0x60_00            | PUSH1 0            | 0                                                        //
            // 0x51    |  0x51               | MLOAD              | byteDeployerAddress                                      //
            // 0xFF    |  0xFF               | SELFDESTRUCT       |                                                          //
            //---------------------------------------------------------------------------------------------------------------//
            // (5 bytes: 67-71 in deployed contract)
            hex"5B_60_00_51_FF",
            //---------------------------------------------------------------------------------------------------------------//
            // (*) Note: this value must be adjusted if selfdestruct purge logic is adjusted, to refer to the correct start  //
            //           offset for where the `msg.sender` address was stored in deployed bytecode.                          //
            //                                                                                                               //
            // (^) Note: this value must be adjusted if portions of the selfdestruct purge logic are adjusted.               //
            //---------------------------------------------------------------------------------------------------------------//
            //
            // store the deploying-contract's address (to be used to gate and call `selfdestruct`),
            // with expected 0-padding to fit a 20-byte address into a 30-byte slot.
            //
            // note: it is important that this address is the executing contract's address
            //      (the address that represents the client-application smart contract of this library)
            //      which means that it is the responsibility of the client-application smart contract
            //      to determine how deletes are gated (or if they are exposed at all) as it is only
            //      this contract that will be able to call `purgeBytecode` as the `CALLER` that is
            //      checked above (op-code 0x33).
            hex"00_00_00_00_00_00_00_00_00_00_00_00", // left-pad 20-byte address with 12 0x00 bytes
            address(this),
            // uploaded data (stored as bytecode) comes last
            _data
        );

        assembly {
            // deploy a new contract with the generated creation code.
            // start 32 bytes into creationCode to avoid copying the byte length.
            address_ := create(0, add(creationCode, 0x20), mload(creationCode))
        }

        // address must be non-zero if contract was deployed successfully
        require(address_ != address(0), "ContractAsStorage: Write Error");
    }

    /*//////////////////////////////////////////////////////////////
                               READ LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Read a string from contract bytecode
     * @param _address address of deployed contract with bytecode containing concat(gated-cleanup-logic, address, data)
     * @return data string read from contract bytecode
     */
    function readFromBytecode(
        address _address
    ) internal view returns (string memory data) {
        // get the size of the bytecode
        uint256 bytecodeSize = _bytecodeSizeAt(_address);
        // handle case where address contains code < DATA_OFFSET
        // note: the first check here also captures the case where
        //       (bytecodeSize == 0) implicitly, but we add the second check of
        //       (bytecodeSize == 0) as a fall-through that will never execute
        //       unless `DATA_OFFSET` is set to 0 at some point.
        if ((bytecodeSize < DATA_OFFSET) || (bytecodeSize == 0)) {
            revert("ContractAsStorage: Read Error");
        }
        // handle case where address contains code >= DATA_OFFSET
        // decrement by DATA_OFFSET to account for purge logic
        uint256 size;
        unchecked {
            size = bytecodeSize - DATA_OFFSET;
        }

        assembly {
            // allocate free memory
            data := mload(0x40)
            // update free memory pointer
            // use and(x, not(0x1f) as cheaper equivalent to sub(x, mod(x, 0x20)).
            // adding 0x1f to size + logic above ensures the free memory pointer
            // remains word-aligned, following the Solidity convention.
            mstore(0x40, add(data, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length of data in first 32 bytes
            mstore(data, size)
            // copy code to memory, excluding the gated-cleanup-logic and address
            extcodecopy(_address, add(data, 0x20), DATA_OFFSET, size)
        }
    }

    /**
     * @notice Get address for deployer for given contract bytecode
     * @param _address address of deployed contract with bytecode containing concat(gated-cleanup-logic, address, data)
     * @return writerAddress address read from contract bytecode
     */
    function getWriterAddressForBytecode(
        address _address
    ) internal view returns (address) {
        // get the size of the data
        uint256 bytecodeSize = _bytecodeSizeAt(_address);
        // handle case where address contains code < DATA_OFFSET
        // note: the first check here also captures the case where
        //       (bytecodeSize == 0) implicitly, but we add the second check of
        //       (bytecodeSize == 0) as a fall-through that will never execute
        //       unless `DATA_OFFSET` is set to 0 at some point.
        if ((bytecodeSize < DATA_OFFSET) || (bytecodeSize == 0)) {
            revert("ContractAsStorage: Read Error");
        }

        assembly {
            // allocate free memory
            let writerAddress := mload(0x40)
            // shift free memory pointer by one slot
            mstore(0x40, add(mload(0x40), 0x20))
            // copy the 32-byte address of the data contract writer to memory
            // note: this relies on the assumption noted at the top-level of
            //       this file that the storage layout for the deployed
            //       contracts-as-storage contract looks like:
            //       | gated-cleanup-logic | deployer-address (padded) | data |
            extcodecopy(
                _address,
                writerAddress,
                ADDRESS_OFFSET,
                0x20 // full 32-bytes, as address is expected to be zero-padded
            )
            return(
                writerAddress,
                0x20 // return size is entire slot, as it is zero-padded
            )
        }
    }

    /*//////////////////////////////////////////////////////////////
                              DELETE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Purge contract bytecode for cleanup purposes
     * note: Although this does reduce usage of Ethereum state, it does not reduce the gas costs of removal
     * transactions. We believe this is the best behavior at the time of writing, and do not expect this to
     * result in any breaking changes in the future. All current proposals to change the self-destruct opcode
     * are backwards compatible, but may result in not removing the bytecode from the blockchain state. This
     * implementation is compatible with that architecture, as it does not rely on the bytecode being removed
     * from the blockchain state (as opposed to using a CREATE2 style opcode when creating bytecode contracts,
     * which could be used in a way that may rely on the bytecode being removed from the blockchain state,
     * e.g. replacing a contract at a given deployed address).
     * @param _address address of deployed contract with bytecode containing concat(gated-cleanup-logic, address, data)
     * @dev This contract is only callable by the address of the contract that originally deployed the bytecode
     *      being purged. If this method is called by any other address, it will revert with the `INVALID` op-code.
     *      Additionally, for security purposes, the contract must be called with calldata `0xFF` to ensure that
     *      the `selfdestruct` op-code is intentionally being invoked, otherwise the `INVALID` op-code will be raised.
     */
    function purgeBytecode(address _address) internal {
        // deployed bytecode (above) handles all logic for purging state, so no
        // call data is expected to be passed along to perform data purge
        (bool success /* `data` not needed */, ) = _address.call(hex"FF");
        if (!success) {
            revert("ContractAsStorage: Delete Error");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Returns the size of the bytecode at address `_address`
        @param _address address that may or may not contain bytecode
        @return size size of the bytecode code at `_address`
    */
    function _bytecodeSizeAt(
        address _address
    ) private view returns (uint256 size) {
        assembly {
            size := extcodesize(_address)
        }
    }
}
