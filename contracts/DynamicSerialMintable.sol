// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "base64-sol/base64.sol";
import "./FundsRecoverable.sol";
import "./ISerialMintable.sol";
import "./IERC2981.sol";

/**
This is a smart contract for handling dynamic contract minting.
*/

contract DynamicSerialMintable is
    ISerialMintable,
    ERC721,
    AccessControl,
    IERC2981,
    ReentrancyGuard
{
    struct SerialConfig {
        string name;
        string description;
        string animationStoragePath;
        string imageStoragePath;
        uint256 serialSize;
        uint256 atSerialId;
        uint256 firstReservedToken;

        // royalties
        address payable royaltyRecipient;
        uint256 royaltyBPS;
    }

    event MintedSerial(uint256 serialId, uint256 tokenId, address minter);

    event CreatedSerial(uint256 serialId);

    uint256 public tokenIdsReserved = 1;
    uint256 public currentSerial = 0;
    SerialConfig[] private serials;
    mapping(uint256 => uint256) private tokenIdToSerialId;
    bytes32 public constant CREATE_SERIAL_ROLE =
        keccak256("CREATE_SERIAL_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        AccessControl._setupRole(AccessControl.DEFAULT_ADMIN_ROLE, msg.sender);
        AccessControl._setupRole(CREATE_SERIAL_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl, IERC165)
        returns (bool)
    {
        return
            type(IERC2981).interfaceId == interfaceId ||
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function mintSerial(uint256 serialId, address to)
        override
        external
        nonReentrant
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        SerialConfig memory serial = serials[serialId];
        return _mintSerial(serial, serialId, to);
    }

    function _mintSerial(
        SerialConfig memory serial,
        uint256 serialId,
        address to
    ) private returns (uint256) {
        require(serial.atSerialId < serial.serialSize, "SOLD OUT");
        uint256 tokenId = serial.firstReservedToken + serial.atSerialId;
        _mint(to, tokenId);
        tokenIdToSerialId[tokenId] = serialId;
        serials[serialId].atSerialId += 1;
        emit MintedSerial(serialId, tokenId, to);
        return tokenId;
    }

    function createSerial(
        string memory name,
        string memory description,
        string memory imageStoragePath,
        string memory animationStoragePath,
        uint256 serialSize,
        uint256 royaltyBPS,
        address payable royaltyRecipient
    ) public onlyRole(CREATE_SERIAL_ROLE) {
        serials.push(
            SerialConfig({
                name: name,
                description: description,
                imageStoragePath: imageStoragePath,
                animationStoragePath: animationStoragePath,
                firstReservedToken: tokenIdsReserved,
                serialSize: serialSize,
                atSerialId: 0,
                royaltyRecipient: royaltyRecipient,
                royaltyBPS: royaltyBPS
            })
        );

        emit CreatedSerial(serials.length - 1);

        tokenIdsReserved += serialSize;
    }

    function getSerial(uint256 serialId)
        public
        view
        returns (SerialConfig memory)
    {
        return serials[serialId];
    }

    function getSerialByToken(uint256 tokenId)
        public
        view
        returns (SerialConfig memory)
    {
        return serials[tokenIdToSerialId[tokenId]];
    }

    function getContentBaseURLs(uint256 tokenId)
        public
        view
        returns (string memory, string memory)
    {
        return (
            serials[tokenIdToSerialId[tokenId]].imageStoragePath,
            serials[tokenIdToSerialId[tokenId]].animationStoragePath
        );
    }

    function updateRoyaltyRecipient(
        uint256 serialId,
        address payable newRecipient
    ) public onlyRole(AccessControl.DEFAULT_ADMIN_ROLE) {
        serials[serialId].royaltyRecipient = newRecipient;
    }

    function _tokenMediaData(SerialConfig memory serial, uint256 tokenOfSerial)
        private
        view
        returns (string memory)
    {
        if (
            bytes(serial.imageStoragePath).length > 0 &&
            bytes(serial.animationStoragePath).length > 0
        ) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        serial.animationStoragePath,
                        "?id=",
                        Strings.toString(tokenOfSerial),
                        '", "animation_url": "',
                        serial.animationStoragePath,
                        "?id=",
                        Strings.toString(tokenOfSerial),
                        '", "'
                    )
                );
        }
        if (bytes(serial.imageStoragePath).length > 0) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        serial.imageStoragePath,
                        "?id=",
                        Strings.toString(tokenOfSerial),
                        '", "'
                    )
                );
        }
        if (bytes(serial.animationStoragePath).length > 0) {
            return
                string(
                    abi.encodePacked(
                        'animation_url": "',
                        serial.animationStoragePath,
                        serial.animationStoragePath,
                        "?id=",
                        '", "'
                    )
                );
        }

        return "";
    }

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external override view returns (
        address receiver,
        uint256 royaltyAmount
    ) {

        SerialConfig memory config = getSerialByToken(_tokenId);
        return (
            config.royaltyRecipient,
            (_salePrice * config.royaltyBPS) / 10_000
        );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "NO TOKEN");

        SerialConfig memory serial = serials[tokenIdToSerialId[tokenId]];
        uint256 tokenOfSerial = tokenId - serial.firstReservedToken + 1;

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name": "',
                            serial.name,
                            " ",
                            Strings.toString(tokenOfSerial),
                            "/",
                            Strings.toString(serial.serialSize),
                            '", "',
                            'description": "',
                            serial.description,
                            '", "',
                            _tokenMediaData(serial, tokenOfSerial),
                            'properties": {"number": ',
                            Strings.toString(tokenOfSerial),
                            ', "name": "',
                            serial.name,
                            '"}}'
                        )
                    )
                )
            );
    }
}
