import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { DynamicSerialMintable, SeriesSale } from "../typechain";

describe("SeriesSale", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: DynamicSerialMintable;
  let seriesSale: SeriesSale;

  beforeEach(async () => {
    const { DynamicSerialMintable, SeriesSale } = await deployments.fixture([
      "DynamicSerialMintable",
      "SeriesSale",
    ]);
    dynamicSketch = (await ethers.getContractAt(
      "DynamicSerialMintable",
      DynamicSerialMintable.address
    )) as DynamicSerialMintable;
    seriesSale = (await ethers.getContractAt(
      "SeriesSale",
      SeriesSale.address
    )) as SeriesSale;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  describe("with a serial", () => {
    beforeEach(async () => {
      await dynamicSketch.createSerial(
        "test",
        "test",
        "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        10,
        10,
        signerAddress
      );
      await dynamicSketch.setAllowedMinters(0, [seriesSale.address]);
    });
    it("allows creating an ETH sale", async () => {
      const [_, s2, s3] = await ethers.getSigners();
      await seriesSale.createRelease(
        true,
        3,
        ethers.utils.parseEther("0.1"),
        await s2.getAddress(),
        dynamicSketch.address,
        0
      );
      await expect(seriesSale.connect(s3).mint(0)).to.be.revertedWith("PAUSED");
      await seriesSale.setPaused(0, false);
      await expect(seriesSale.connect(s3).mint(0)).to.be.revertedWith("PRICE");
      await expect(
        seriesSale.connect(s3).mint(0, { value: 100 })
      ).to.be.revertedWith("PRICE");
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
      ).to.be.revertedWith("FINISHED");
    });
  });
});
