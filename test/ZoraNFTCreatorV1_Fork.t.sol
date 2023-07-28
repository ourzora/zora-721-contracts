// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import "../src/ZoraNFTCreatorV1.sol";
import "../src/ZoraNFTCreatorProxy.sol";
import {MockMetadataRenderer} from "./metadata/MockMetadataRenderer.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";
import {ForkHelper} from "./utils/ForkHelper.sol";
import {DropDeployment , ChainConfig} from "../src/DeploymentConfig.sol";

contract ZoraNFTCreatorV1_ForkTests is Test, ForkHelper {
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));

    function test_fork_CreateEdition() external {
        string[] memory forkTestChains = getForkTestChains();

        DropDeployment memory deployment;
        ChainConfig memory chainConfig;

        for (uint256 i = 0; i < forkTestChains.length; i++) {
            string memory chainName = forkTestChains[i];

            vm.createSelectFork(vm.rpcUrl(chainName ));
        
            // get the deployment for the current chain id.
            deployment = getDeployment();
            chainConfig = getChainConfig();

            address factoryAddress = deployment.factory;
            ZoraNFTCreatorV1 factory = ZoraNFTCreatorV1(factoryAddress);

            assertEq(chainConfig.factoryOwner, OwnableUpgradeable(factoryAddress).owner(), string.concat("configured owner incorrect on: ", chainName));
            assertEq(deployment.dropMetadata, address(factory.dropMetadataRenderer()), string.concat("configured drop metadata renderer incorrect on: ", chainName));
            assertEq(deployment.editionMetadata, address(factory.editionMetadataRenderer()), string.concat("configured edition metadata renderer incorrect on: ", chainName));
            // assertEq(deployment.dropImplementation, address(factory.editionMetadataRenderer()), string.concat("configured metadata renderer incorrect on: ", chainName));

            address deployedEdition = factory.createEdition(
                "name",
                "symbol",
                100,
                500,
                DEFAULT_FUNDS_RECIPIENT_ADDRESS,
                DEFAULT_FUNDS_RECIPIENT_ADDRESS,
                IERC721Drop.SalesConfiguration({
                    publicSaleStart: 0,
                    publicSaleEnd: type(uint64).max,
                    presaleStart: 0,
                    presaleEnd: 0,
                    publicSalePrice: 0.1 ether,
                    maxSalePurchasePerAddress: 0,
                    presaleMerkleRoot: bytes32(0)
                }),
                "desc",
                "animation",
                "image",
                DEFAULT_CREATE_REFERRAL
            );
            ERC721Drop drop = ERC721Drop(payable(deployedEdition));
            (, uint256 fee) = drop.zoraFeeForAmount(10);
            vm.startPrank(DEFAULT_FUNDS_RECIPIENT_ADDRESS);
            vm.deal(DEFAULT_FUNDS_RECIPIENT_ADDRESS, 10 ether + fee);
            drop.purchase{value: 1 ether + fee}(10);
            assertEq(drop.totalSupply(), 10);
            
        }
    }
}