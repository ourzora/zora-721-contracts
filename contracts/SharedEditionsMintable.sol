// SPDX-License-Identifier: GPL-3.0

/**
█▄░█ █▀▀ ▀█▀   █▀▀ █▀▄ █ ▀█▀ █ █▀█ █▄░█ █▀
█░▀█ █▀░ ░█░   ██▄ █▄▀ █ ░█░ █ █▄█ █░▀█ ▄█

▀█ █▀█ █▀█ ▄▀█
█▄ █▄█ █▀▄ █▀█
 */

pragma solidity 0.8.6;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC2981, IERC165} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./ISerialMultipleMintable.sol";
import "./SharedNFTLogic.sol";

/**
    This is a smart contract for handling dynamic contract minting.

    @dev This allows creators to mint a series 
    @author iain nash
    Repository: https://github.com/ourzora/nft-serial-contracts/
*/
contract SharedEditionsMintable is
    ISerialMultipleMintable,
    ERC721,
    IERC2981
{
    struct SerialConfig {
        // metadata
        // name for the nft metadata in format $NAME $ID/$COUNT
        string name;
        // description for the nft metadata
        string description;
        // media urls
        // animation_url field in the metadata
        string animationUrl;
        // hash for the associated animation
        bytes32 animationHash;
        // image in the metadata
        string imageUrl;
        // hash for the associated image
        bytes32 imageHash;
        // allowed to update urls and royalty address, can reassign ownership + serial bookkeeping for creator
        address owner;
        // total size of serial that can be minted
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

    // Emitted when a serial is minted for indexing purposes.
    event MintedSerial(uint256 serialId, uint256 tokenId, address minter);

    // Emitted when a serial is created reserving the corresponding token IDs.
    event CreatedSerial(
        uint256 serialId,
        address creator,
        uint256 startToken,
        uint256 serialSize
    );

    // Public counter keeping tracked of the token ids reserved
    uint256 public tokenIdsReserved = 1;

    // Keeps track of the next serial ID to be created (at 0 = no serials, at 1 = 0th serial is created)
    uint256 public currentSerial = 0;

    // Account that is allowed to create serials. This can be re-assigned and when is the ZeroAddress anyone can create serials with this contract.
    address public allowedCreator;

    SharedNFTLogic private immutable sharedNFTLogic;

    // List of serials that can be minted on this contract.
    SerialConfig[] private serials;

    // Mapping from token id to serial id. Used to lookup serial information
    // Optimization for runtime gas that prevents searching through an array of serials.
    mapping(uint256 => uint256) private tokenIdToSerialId;

    // Used to check that the serial passed in exists in the config.
    modifier serialExists(uint256 serialId) {
        require(serials[serialId].serialSize > 0, "Serial needs to exist");
        _;
    }

    // Used to check that the serial owner is the person sending the request.
    modifier ownsSerial(uint256 serialId) {
        require(msg.sender == serials[serialId].owner, "Serial wrong owner");
        _;
    }

    /**
      @param name Name of NFT contract
      @param symbol Symbol of NFT contract
      @param _allowedCreator address allowed to create new Serials (aka Owner)
      @dev Sets up the serial contract with a name, symbol, and an initial allowed creator.
     */
    constructor(
        string memory name,
        string memory symbol,
        SharedNFTLogic _sharedNFTLogic,
        address _allowedCreator
    ) ERC721(name, symbol) {
        allowedCreator = _allowedCreator;
        sharedNFTLogic = _sharedNFTLogic;
    }

    /**
      @param serialId id of the serial to check if the msg.sender is allowed to mint
      @dev This helper function checks if the msg.sender is allowed to mint the
            given serial id.
     */
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

    /**
      @param tokenId token id to retrieve the owner for
      @dev This retrieves the original owner/creator of the serial for a given tokenId
     */
    function creator(uint256 tokenId) public view returns (address) {
        return getSerialByToken(tokenId).owner;
    }

    /**
      @param newCreator address to re-assign the creator permission to
      @dev This re-assigns the ethereum address that is allowed to create serials on this contract.
      To "freeze" a contract to prevent any more serials being created, this can be set to 0x0.
     */
    function setAllowedCreator(address newCreator) public {
        require(msg.sender == allowedCreator, "Wrong serial owner");
        allowedCreator = newCreator;
    }

    /**
      @param serialId ID of the serial to mint
      @param to address to send the newly minted serial to
      @dev This mints one serial to the given address by an allowed minter on the serial instance.
     */
    function mintSerial(uint256 serialId, address to)
        external
        override
        serialExists(serialId)
        returns (uint256)
    {
        require(_isAllowedToMint(serialId), "Needs to be an allowed minter");
        address[] memory toMint = new address[](1);
        toMint[0] = to;
        return _mintSerials(serialId, toMint);
    }

    /**
      @param serialId ID of the serial to mint
      @param recipients list of addresses to send the newly minted serials to
      @dev This mints multiple serials to the given list of addresses.
     */
    function mintSerials(uint256 serialId, address[] memory recipients)
        external
        override
        serialExists(serialId)
        returns (uint256)
    {
        require(_isAllowedToMint(serialId), "Needs to be an allowed minter");
        return _mintSerials(serialId, recipients);
    }

    /**
      @param serialId id of the serial to re-assign owner of
      @param owner Owner to reassign serial of
      @dev Reassigns the serial id to a new owners.
           Owners can update allowed minters and update URLs of a serial.
     */
    function setOwner(uint256 serialId, address owner)
        public
        serialExists(serialId)
        ownsSerial(serialId)
    {
        serials[serialId].owner = owner;
    }

    /**
      @param serialId serial to to update the minters for
      @param allowedMinters list of addresses allowed to mint this serial
      @dev Set the allowed minters array for a given serial id
           This requires that msg.sender is the owner of the given serial id.
     */
    function setAllowedMinters(
        uint256 serialId,
        address[] memory allowedMinters
    ) public serialExists(serialId) ownsSerial(serialId) {
        serials[serialId].allowedMinters = allowedMinters;
    }

    /**
      @dev Allows for updates of serial urls by the owner of the serial.
           Only URLs can be updated (data-uris are supported), hashes cannot be updated.
     */
    function updateSerialURLs(
        uint256 serialId,
        string memory imageUrl,
        string memory animationUrl
    ) public serialExists(serialId) ownsSerial(serialId) {
        serials[serialId].imageUrl = imageUrl;
        serials[serialId].animationUrl = animationUrl;
    }

    /**
      @dev Update the royalty recipient address
           Can only be called by the serial owner.
     */
    function updateRoyaltyRecipient(
        uint256 serialId,
        address payable newRecipient
    ) public serialExists(serialId) ownsSerial(serialId) {
        serials[serialId].royaltyRecipient = newRecipient;
    }

    /**
      @dev Private function to mint serials without any access checks.
           Called by the public serial minting functions.
     */
    function _mintSerials(uint256 serialId, address[] memory recipients)
        private
        returns (uint256)
    {
        SerialConfig memory serial = getSerial(serialId);
        uint256 startId = serial.firstReservedToken + serial.atSerialId;
        require(
            serial.atSerialId + recipients.length <= serial.serialSize,
            "SOLD OUT"
        );
        uint256 toMint = 0;
        uint256 tokenId;
        while (toMint < recipients.length) {
            tokenId = startId + toMint;
            _mint(recipients[toMint], tokenId);
            tokenIdToSerialId[tokenId] = serialId;
            emit MintedSerial(serialId, tokenId, recipients[toMint]);
            toMint += 1;
        }
        serials[serialId].atSerialId += recipients.length;
        return tokenId;
    }

    /**
      @param name Name of serial, used in the title as "$NAME NUMBER/TOTAL"
      @param description Description of serial, used in the description field of the NFT
      @param imageUrl Image URL of the serial. Strongly encouraged to be used, if necessary, only animation URL can be used. One of animation and image url need to exist in a serial to render the NFT.
      @param imageHash SHA256 of the given image in bytes32 format (0xHASH). If no image is included, the hash can be zero (bytes32 type)
      @param animationUrl Animation URL of the serial. Not required, but if omitted image URL needs to be included. This follows the opensea spec for NFTs
      @param animationHash The associated hash of the animation in sha-256 bytes32 format. If animation is omitted 
      @param serialSize Number of serials that can be minted in total.
      @param royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
      @param royaltyRecipient Recipient address of the royalty for resales
      @dev Function to create a new serial. Can only be called by the allowed creator
           Sets the only allowed minter to the address that creates/owns the serial.
           This can be re-assigned or updated later
     */
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

        return sharedNFTLogic.createMetadataSerial(
            serial.name,
            serial.description,
            serial.imageUrl,
            serial.animationUrl,
            tokenOfSerial,
            serial.serialSize
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
