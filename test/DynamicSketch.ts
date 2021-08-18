import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { DynamicSerialMintable } from "../typechain";

describe("DynamicSerialMintable", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: DynamicSerialMintable;

  beforeEach(async () => {
    await deployments.fixture(["DynamicSerialMintable"]);
    dynamicSketch = (await ethers.getContractAt(
      "DynamicSerialMintable",
      (
        await deployments.get("DynamicSerialMintable")
      ).address
    )) as DynamicSerialMintable;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  it("makes a new serial", async () => {
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

    const serialResult = await dynamicSketch.getSerial(0);
    expect(serialResult.name).to.be.equal("test");
    expect(serialResult.description).to.be.equal("test");
    expect(serialResult.imageUrl).to.be.equal(
      "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy"
    );
    expect(serialResult.animationUrl).to.be.equal("");
    expect(serialResult.serialSize).to.be.equal(10);
    expect(serialResult.royaltyBPS).to.be.equal(10);
    expect(serialResult.royaltyRecipient).to.be.equal(signerAddress);
  });
  describe("with a serial", () => {
    let signer1: SignerWithAddress;
    beforeEach(async () => {
      signer1 = (await ethers.getSigners())[1];
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
    });
    it("creates a new serial", async () => {
      expect(await signer1.getBalance()).to.eq(
        ethers.utils.parseEther("10000")
      );

      // Mint first serial
      await expect(dynamicSketch.mintSerial(0, signerAddress))
        .to.emit(dynamicSketch, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          signerAddress,
          1
        );

      const tokenURI = await dynamicSketch.tokenURI(1);
      const parsedTokenURI = parseDataURI(tokenURI);
      if (!parsedTokenURI) {
        throw "No parsed token uri";
      }

      // Check metadata from serial
      const uriData = Buffer.from(parsedTokenURI.body).toString("utf-8");
      const metadata = JSON.parse(uriData);

      expect(parsedTokenURI.mimeType.type).to.equal("application");
      expect(parsedTokenURI.mimeType.subtype).to.equal("json");
      // expect(parsedTokenURI.mimeType.parameters.get("charset")).to.equal(
      //   "utf-8"
      // );
      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "test 1/10",
          description: "test",
          image:
            "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy?id=1",
          properties: { number: 1, name: "test" },
        })
      );
    });
    it("creates an authenticated serial", async () => {
      await dynamicSketch.mintSerial(0, await signer1.getAddress());
      expect(await dynamicSketch.ownerOf(1)).to.equal(
        await signer1.getAddress()
      );
    });
    it("stops after serials are sold out", async () => {
      const [_, signer1] = await ethers.getSigners();

      // Mint first serial
      for (var i = 1; i <= 10; i++) {
        await expect(dynamicSketch.mintSerial(0, await signer1.getAddress()))
          .to.emit(dynamicSketch, "Transfer")
          .withArgs(
            "0x0000000000000000000000000000000000000000",
            await signer1.getAddress(),
            i
          );
      }

      await expect(
        dynamicSketch.mintSerial(0, signerAddress)
      ).to.be.revertedWith("SOLD OUT");

      const tokenURI = await dynamicSketch.tokenURI(10);
      const parsedTokenURI = parseDataURI(tokenURI);
      if (!parsedTokenURI) {
        throw "No parsed token uri";
      }

      // Check metadata from serial
      const uriData = Buffer.from(parsedTokenURI.body).toString("utf-8");
      console.log({ tokenURI, uriData });
      const metadata = JSON.parse(uriData);

      expect(parsedTokenURI.mimeType.type).to.equal("application");
      expect(parsedTokenURI.mimeType.subtype).to.equal("json");
      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "test 10/10",
          description: "test",
          image:
            "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy?id=10",
          properties: { number: 10, name: "test" },
        })
      );
    });
  });
});
