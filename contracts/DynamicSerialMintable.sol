// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
    IERC2981,
    ReentrancyGuard
{
    struct SerialConfig {
        // metadata
        string name;
        string description;
        // media links
        string animationUrl;
        bytes32 animationHash;
        string imageUrl;
        bytes32 imageHash;
        // access + serial bookkeeping
        address owner;
        // total size of serial
        uint256 serialSize;
        // current token id minted
        uint256 atSerialId;
        // id serial starts at
        uint256 firstReservedToken;
        // royalty address
        address payable royaltyRecipient;
        // royalty amount in bps
        uint256 royaltyBPS;
        // addresses allowed to mint serial
        address[] allowedMinters;
    }

    event MintedSerial(uint256 serialId, uint256 tokenId, address minter);

    event CreatedSerial(
        uint256 serialId,
        address creator,
        uint256 startToken,
        uint256 serialSize
    );

    uint256 public tokenIdsReserved = 1;
    uint256 public currentSerial = 0;
    address public allowedCreator;
    SerialConfig[] private serials;
    mapping(uint256 => uint256) private tokenIdToSerialId;

    modifier serialExists(uint256 serialId) {
        require(serials[serialId].serialSize > 0, "Serial needs to exist");
        _;
    }
    modifier ownsSerial(uint256 serialId) {
        require(msg.sender == serials[serialId].owner, "Serial wrong owner");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address creator
    ) ERC721(name, symbol) {
        allowedCreator = creator;
    }

    function _isAllowedToMint(uint256 serialId) internal view returns (bool) {
        SerialConfig memory serial = getSerial(serialId);
        uint256 allowedMintersCount = serial.allowedMinters.length;
        if (allowedMintersCount == 0) {
            return true;
        }
        for (uint256 i = 0; i < allowedMintersCount; i++) {
            if (serial.allowedMinters[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    function creator(uint256 tokenId) public view returns (address) {
        return getSerialByToken(tokenId).owner;
    }

    function mintSerial(uint256 serialId, address to)
        external
        override
        nonReentrant
        serialExists(serialId)
        returns (uint256)
    {
        require(_isAllowedToMint(serialId), "Needs to be an allowed minter");
        return _mintSerial(serialId, to);
    }

    function setOwner(uint256 serialId, address owner)
        public
        serialExists(serialId)
        ownsSerial(serialId)
    {
        serials[serialId].owner = owner;
    }

    function setAllowedMinters(
        uint256 serialId,
        address[] memory allowedMinters
    ) public serialExists(serialId) ownsSerial(serialId) {
        serials[serialId].allowedMinters = allowedMinters;
    }

    function updateSerialURLs(
        uint256 serialId,
        string memory imageUrl,
        string memory animationUrl
    ) public serialExists(serialId) ownsSerial(serialId) {
        serials[serialId].imageUrl = imageUrl;
        serials[serialId].animationUrl = animationUrl;
    }

    function updateRoyaltyRecipient(
        uint256 serialId,
        address payable newRecipient
    ) public serialExists(serialId) ownsSerial(serialId) {
        serials[serialId].royaltyRecipient = newRecipient;
    }

    function _mintSerial(uint256 serialId, address to)
        private
        returns (uint256)
    {
        SerialConfig memory serial = getSerial(serialId);
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
        string memory imageUrl,
        bytes32 imageHash,
        string memory animationUrl,
        bytes32 animationHash,
        uint256 serialSize,
        uint256 royaltyBPS,
        address payable royaltyRecipient
    ) public {
        require(
            allowedCreator == address(0x0) || allowedCreator == msg.sender,
            "Only authed"
        );
        address[] memory allowedMinters = new address[](1);
        allowedMinters[0] = msg.sender;

        serials.push(
            SerialConfig({
                name: name,
                description: description,
                owner: msg.sender,
                imageHash: imageHash,
                imageUrl: imageUrl,
                animationUrl: animationUrl,
                animationHash: animationHash,
                firstReservedToken: tokenIdsReserved,
                serialSize: serialSize,
                atSerialId: 0,
                royaltyRecipient: royaltyRecipient,
                royaltyBPS: royaltyBPS,
                allowedMinters: allowedMinters
            })
        );

        emit CreatedSerial(
            serials.length - 1,
            msg.sender,
            tokenIdsReserved,
            serialSize
        );

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

    function getURIs(uint256 tokenId)
        public
        view
        returns (
            string memory,
            bytes32,
            string memory,
            bytes32
        )
    {
        SerialConfig memory serial = getSerialByToken(tokenId);
        return (
            serial.imageUrl,
            serial.imageHash,
            serial.animationUrl,
            serial.animationHash
        );
    }

    function _tokenMediaData(SerialConfig memory serial, uint256 tokenOfSerial)
        private
        pure
        returns (string memory)
    {
        bool hasImage = bytes(serial.imageUrl).length > 0;
        bool hasAnimation = bytes(serial.animationUrl).length > 0;
        if (hasImage && hasAnimation) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        serial.imageUrl,
                        "?id=",
                        Strings.toString(tokenOfSerial),
                        '", "animation_url": "',
                        serial.animationUrl,
                        "?id=",
                        Strings.toString(tokenOfSerial),
                        '", "'
                    )
                );
        }
        if (hasImage) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        serial.imageUrl,
                        "?id=",
                        Strings.toString(tokenOfSerial),
                        '", "'
                    )
                );
        }
        if (hasAnimation) {
            return
                string(
                    abi.encodePacked(
                        'animation_url": "',
                        serial.animationUrl,
                        "?id=",
                        '", "'
                    )
                );
        }

        return "";
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, IERC165)
        returns (bool)
    {
        return
            type(IERC2981).interfaceId == interfaceId ||
            ERC721.supportsInterface(interfaceId);
    }
}
