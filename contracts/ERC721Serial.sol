// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FundsRecoverable.sol";

/**



*/

contract ERC721SerialFactory is
    ERC721,
    AccessControl,
    ReentrancyGuard,
    FundsRecoverable
{
    struct SerialConfig {
        string name;
        string description;
        string animationStoragePath;
        string imageStoragePath;
        address payable purchaseRecipient;
        uint256 ethPrice;
        uint256 serialSize;
        uint256 atSerialId;
        bool paused;
        uint256 firstReservedToken;
    }

    event MintedSerial(uint256 serialId, uint256 tokenId, address minter);

    event CreatedSerial(uint256 serialId);

    event SetSerialPaused(uint256 serialId, bool isPaused);

    uint256 public tokenIdsReserved = 1;
    uint256 public currentSerial = 0;
    string ipfsBaseUrl = "https://ipfs.io/ipfs/";
    SerialConfig[] private serials;
    mapping(uint256 => uint256) private tokenIdToSerialId;
    bytes32 public constant CREATE_SERIAL_ROLE =
        keccak256("CREATE_SERIAL_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        AccessControl._setupRole(AccessControl.DEFAULT_ADMIN_ROLE, msg.sender);
        AccessControl._setupRole(CREATE_SERIAL_ROLE, msg.sender);
    }

    function setIPFSBase(string memory newIpfsBaseUrl)
        public
        onlyRole(AccessControl.DEFAULT_ADMIN_ROLE)
    {
        ipfsBaseUrl = newIpfsBaseUrl;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function mintSerial(uint256 serialId)
        public
        payable
        nonReentrant
        returns (uint256)
    {
        SerialConfig memory serial = serials[serialId];
        require(!serial.paused, "PAUSED");
        require(msg.value == serial.ethPrice, "WRONG PRICE");
        if (serial.ethPrice > 0x0) {
            (bool sent, bytes memory _data) = serial.purchaseRecipient.call{
                value: msg.value
            }("");
            require(sent, "Failed to send Ether");
        }

        return _mintSerial(serial, serialId, msg.sender);
    }

    function mintSerialAuthenticated(uint256 serialId, address to)
        public
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
        uint256 ethPrice,
        address payable purchaseRecipient,
        uint256 serialSize,
        bool paused
    ) public onlyRole(CREATE_SERIAL_ROLE) {
        serials.push(
            SerialConfig({
                name: name,
                description: description,
                imageStoragePath: imageStoragePath,
                animationStoragePath: animationStoragePath,
                ethPrice: ethPrice,
                firstReservedToken: tokenIdsReserved,
                purchaseRecipient: purchaseRecipient,
                serialSize: serialSize,
                paused: paused,
                atSerialId: 0
            })
        );

        emit SetSerialPaused(serials.length - 1, paused);
        emit CreatedSerial(serials.length - 1);

        tokenIdsReserved += serialSize;
    }

    function setSerialPaused(uint256 serialId, bool paused)
        public
        onlyRole(CREATE_SERIAL_ROLE)
    {
        emit SetSerialPaused(serialId, paused);
        serials[serialId].paused = paused;
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

    function getContentIPFSCids(uint256 tokenId)
        public
        view
        returns (string memory, string memory)
    {
        return (
            serials[tokenIdToSerialId[tokenId]].imageStoragePath,
            serials[tokenIdToSerialId[tokenId]].animationStoragePath
        );
    }

    function getSerialRecipient(uint256 serialId)
        public
        view
        returns (address)
    {
        return serials[serialId].purchaseRecipient;
    }

    function updateSerialRecipient(
        uint256 serialId,
        address payable newRecipient
    ) public onlyRole(CREATE_SERIAL_ROLE) {
        serials[serialId].purchaseRecipient = newRecipient;
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
                        ipfsBaseUrl,
                        serial.animationStoragePath,
                        "?id=",
                        Strings.toString(tokenOfSerial),
                        '", "animation_url": "',
                        ipfsBaseUrl,
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
                        ipfsBaseUrl,
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
                        ipfsBaseUrl,
                        serial.animationStoragePath,
                        serial.animationStoragePath,
                        "?id=",
                        '", "'
                    )
                );
        }

        return "";
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
                    'data:application/json;charset=utf-8,{"name": "',
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
            );
    }
}
