import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  SingleEditionMintable,
  SingleEditionMintableCreator,
  SingleEditionSeriesSale,
} from "../typechain";

describe("SingleEditionSeriesSale", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketchCreator: SingleEditionMintableCreator;
  let dynamicSketch: SingleEditionMintable;
  let seriesSale: SingleEditionSeriesSale;

  beforeEach(async () => {
    const { SingleEditionMintableCreator, SingleEditionSeriesSale } =
      await deployments.fixture([
        "SingleEditionMintableCreator",
        "SingleEditionSeriesSale",
      ]);
    dynamicSketchCreator = (await ethers.getContractAt(
      "SingleEditionMintableCreator",
      SingleEditionMintableCreator.address
    )) as SingleEditionMintableCreator;
    seriesSale = (await ethers.getContractAt(
      "SingleEditionSeriesSale",
      SingleEditionSeriesSale.address
    )) as SingleEditionSeriesSale;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  describe("with a serial", () => {
    beforeEach(async () => {
      await dynamicSketchCreator.createSerial(
        "test sale serial",
        "TSALE",
        "Serial for testing the sale",
        "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        10,
        10
      );
      const newSerialAddress = await dynamicSketchCreator.getSerialAtId(0);
      dynamicSketch = (await ethers.getContractAt(
        "SingleEditionMintable",
        newSerialAddress
      )) as SingleEditionMintable;
      await dynamicSketch.setApprovedMinter(seriesSale.address, true);
    });
    it("allows creating an ETH sale", async () => {
      const [_, s2, s3] = await ethers.getSigners();
      await seriesSale.createRelease(
        true,
        3,
        ethers.utils.parseEther("0.1"),
        dynamicSketch.address
      );
      await expect(seriesSale.connect(s3).mint(0)).to.be.revertedWith("Paused");
      await seriesSale.setPaused(0, false);
      expect(seriesSale.connect(s2).setPaused(0, false)).to.be.revertedWith(
        "Not owner"
      );
      await expect(seriesSale.connect(s3).mint(0)).to.be.revertedWith("Wrong price");
      await expect(
        seriesSale.connect(s3).mint(0, { value: 100 })
      ).to.be.revertedWith("Wrong price");
      await seriesSale
        .connect(s3)
        .mint(0, { value: ethers.utils.parseEther("0.1") });
      expect(
        await dynamicSketch.connect(s3).balanceOf(await s3.getAddress())
      ).to.be.equal(1);
      await seriesSale
        .connect(s2)
        .mint(0, { value: ethers.utils.parseEther("0.1") });
      await seriesSale
        .connect(s3)
        .mint(0, { value: ethers.utils.parseEther("0.1") });
      await expect(
        seriesSale
          .connect(s3)
          .mint(0, { value: ethers.utils.parseEther("0.1") })
      ).to.be.revertedWith("Sold out");
    });
  });
});
