import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { DynamicSerialCreator, DynamicSerialMintable } from "../typechain";

describe("DynamicSerialMintable", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: DynamicSerialCreator;

  beforeEach(async () => {
    const {DynamicSerialCreator} = await deployments.fixture(["DynamicSerialCreator", "DynamicSerialMintable"]);
    const dynamicMintableAddress = (
        await deployments.get("DynamicSerialMintable")
      ).address;
    dynamicSketch = (await ethers.getContractAt(
      "DynamicSerialCreator",
      DynamicSerialCreator.address,
    )) as DynamicSerialCreator;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  it("makes a new serial", async () => {
    await dynamicSketch.createSerial(
      "Testing Token",
      "TEST",
      "This is a testing token for all",
      "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      10,
      10
    );

    const serialResult = await dynamicSketch.getSerialAtId(0);
    const minterContract = (await ethers.getContractAt(
      "DynamicSerialMintable",
      serialResult
    )) as DynamicSerialMintable;
    expect(await minterContract.name()).to.be.equal("Testing Token");
    expect(await minterContract.symbol()).to.be.equal("TEST");
    expect(await minterContract.getURIs()).to.be.equal([
      "",
      "",
      "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
      "",
    ]);
    expect(await minterContract.serialSize()).to.be.equal(10);
    // TODO(iain): check bps
    expect(await minterContract.owner()).to.be.equal(signerAddress);
  });
  describe("with a serial", () => {
    let signer1: SignerWithAddress;
    let minterContract: DynamicSerialMintable;
    beforeEach(async () => {
      signer1 = (await ethers.getSigners())[1];
      await dynamicSketch.createSerial(
        "Testing Token",
        "TEST",
        "This is a testing token for all",
        "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        10,
        10
      );
  
      const serialResult = await dynamicSketch.getSerialAtId(0);
      minterContract = (await ethers.getContractAt(
        "DynamicSerialMintable",
        serialResult
      )) as DynamicSerialMintable;
    });
    it("creates a new serial", async () => {
      expect(await signer1.getBalance()).to.eq(
        ethers.utils.parseEther("10000")
      );

      // Mint first serial
      await expect(minterContract.mintSerial(signerAddress))
        .to.emit(minterContract, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          signerAddress,
          1
        );

      const tokenURI = await minterContract.tokenURI(1);
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
      await minterContract.mintSerial(await signer1.getAddress());
      expect(await minterContract.ownerOf(1)).to.equal(
        await signer1.getAddress()
      );
    });
    it("creates a set of serials", async () => {
      const [s1, s2, s3] = await ethers.getSigners();
      await minterContract.mintSerials([
        await s1.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
      ]);
      expect(await minterContract.ownerOf(1)).to.equal(await s1.getAddress());
      expect(await minterContract.ownerOf(2)).to.equal(await s2.getAddress());
      expect(await minterContract.ownerOf(3)).to.equal(await s3.getAddress());
      await minterContract.mintSerials([
        await s1.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
      ]);
      await expect(dynamicSketch.mintSerials(0, [signerAddress])).to.be
        .reverted;
      await expect(dynamicSketch.mintSerial(0, signerAddress)).to.be.reverted;
    });
    it("stops after serials are sold out", async () => {
      const [_, signer1] = await ethers.getSigners();

      // Mint first serial
      for (var i = 1; i <= 10; i++) {
        await expect(minterContract.mintSerial(await signer1.getAddress()))
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
