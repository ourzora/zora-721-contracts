import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { DynamicSketch } from "../typechain/DynamicSketch";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("ERC721Serial", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: DynamicSketch;

  beforeEach(async () => {
    await deployments.fixture(['DynamicSketch']);
    dynamicSketch = (await deployments.get('DynamicSketch')) as DynamicSketch;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  it("makes a new serial", async () => {
    await serialInstance.createSerial(
      "test",
      "test",
      "QmUh7MKf1AXjn1L8ruM8fQCAKp39o7dfrxQqKnfzFXf15W",
      "",
      ethers.utils.parseEther("0.05"),
      signerAddress,
      10,
      true
    );

    const serialResult = await serialInstance.getSerial(0);
    expect(serialResult.name).to.be.equal("test");
    expect(serialResult.description).to.be.equal("test");
    expect(serialResult.imageStoragePath).to.be.equal(
      "QmUh7MKf1AXjn1L8ruM8fQCAKp39o7dfrxQqKnfzFXf15W"
    );
    expect(serialResult.animationStoragePath).to.be.equal("");
    expect(serialResult.ethPrice).to.be.equal(ethers.utils.parseEther("0.05"));
    expect(serialResult.serialSize).to.be.equal(10);
    expect(serialResult.paused).to.be.equal(true);
  });
  describe("with a serial", () => {
    let signer1: SignerWithAddress;
    beforeEach(async () => {
      signer1 = (await ethers.getSigners())[1];
      await serialInstance.createSerial(
        "test",
        "test",
        "QmUh7MKf1AXjn1L8ruM8fQCAKp39o7dfrxQqKnfzFXf15W",
        "",
        ethers.utils.parseEther("0.05"),
        await signer1.getAddress(),
        10,
        false
      );
    });
    it("creates a new serial", async () => {
      expect(await signer1.getBalance()).to.eq(
        ethers.utils.parseEther("10000")
      );

      // Mint first serial
      await serialInstance.setSerialPaused(0, false);
      await expect(
        serialInstance.mintSerial(0, {
          value: ethers.utils.parseEther("0.05"),
        })
      )
        .to.emit(serialInstance, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          signerAddress,
          1
        );

      expect(await signer1.getBalance()).to.equal(
        ethers.utils.parseEther("10000.05")
      );

      const tokenURI = await serialInstance.tokenURI(1);
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
            "https://ipfs.io/ipfs/QmUh7MKf1AXjn1L8ruM8fQCAKp39o7dfrxQqKnfzFXf15W?id=1",
          properties: {
            number: 1,
            name: "test",
          },
        })
      );
    });
    it("creates an authenticated serial", async () => {
      await serialInstance.grantRole(
        ethers.utils.keccak256(Buffer.from("MINTER_ROLE")),
        signerAddress
      );
      await serialInstance.mintSerialAuthenticated(
        0,
        await signer1.getAddress()
      );
      expect(await serialInstance.ownerOf(1)).to.equal(await signer1.getAddress());
    });
    it("stops after serials are sold out", async () => {
      const [_, signer1] = await ethers.getSigners();

      await serialInstance.createSerial(
        "test",
        "test",
        "QmUh7MKf1AXjn1L8ruM8fQCAKp39o7dfrxQqKnfzFXf15W",
        "",
        ethers.utils.parseEther("0.05"),
        await signer1.getAddress(),
        10,
        true
      );

      // Mint first serial
      await serialInstance.setSerialPaused(0, false);
      for (var i = 1; i <= 10; i++) {
        await expect(
          serialInstance.mintSerial(0, {
            value: ethers.utils.parseEther("0.05"),
          })
        )
          .to.emit(serialInstance, "Transfer")
          .withArgs(
            "0x0000000000000000000000000000000000000000",
            signerAddress,
            i
          );
      }

      await expect(
        serialInstance.mintSerial(0, {
          value: ethers.utils.parseEther("0.05"),
        })
      ).to.be.revertedWith("SOLD OUT");

      const tokenURI = await serialInstance.tokenURI(10);
      const parsedTokenURI = parseDataURI(tokenURI);
      if (!parsedTokenURI) {
        throw "No parsed token uri";
      }

      // Check metadata from serial
      const uriData = Buffer.from(parsedTokenURI.body).toString("utf-8");
      console.log({tokenURI, uriData})
      expect(false).to.equal(true);
      const metadata = JSON.parse(uriData);

      expect(parsedTokenURI.mimeType.type).to.equal("application");
      expect(parsedTokenURI.mimeType.subtype).to.equal("json");
      // expect(parsedTokenURI.mimeType.parameters.get("charset")).to.equal(
      //   "utf-8"
      // );
      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "test 10/10",
          description: "test",
          image:
            "https://ipfs.io/ipfs/QmUh7MKf1AXjn1L8ruM8fQCAKp39o7dfrxQqKnfzFXf15W?id=10",
          properties: {
            number: 10,
            name: "test",
          },
        })
      );
    });
  });
});
