import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  SingleEditionMintableCreator,
  SingleEditionMintable,
} from "../typechain";

describe("SingleEditionMintable", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: SingleEditionMintableCreator;

  beforeEach(async () => {
    const { SingleEditionMintableCreator } = await deployments.fixture([
      "SingleEditionMintableCreator",
      "SingleEditionMintable",
    ]);
    const dynamicMintableAddress = (
      await deployments.get("SingleEditionMintable")
    ).address;
    dynamicSketch = (await ethers.getContractAt(
      "SingleEditionMintableCreator",
      SingleEditionMintableCreator.address
    )) as SingleEditionMintableCreator;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  it("purchases a serial", async () => {
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
      "SingleEditionMintable",
      serialResult
    )) as SingleEditionMintable;
    expect(await minterContract.name()).to.be.equal("Testing Token");
    expect(await minterContract.symbol()).to.be.equal("TEST");

    const [_, s2] = await ethers.getSigners();
    await expect(minterContract.purchase()).to.be.revertedWith("Not for sale");
    await expect(
      minterContract.connect(s2).setSalePrice(ethers.utils.parseEther("0.2"))
    ).to.be.revertedWith("Ownable: caller is not the owner");
    expect(
      await minterContract.setSalePrice(ethers.utils.parseEther("0.2"))
    ).to.emit(minterContract, "PriceChanged");
    expect(
      await minterContract
        .connect(s2)
        .purchase({ value: ethers.utils.parseEther("0.2") })
    ).to.emit(minterContract, "EditionSold");
    const signerBalance = await signer.getBalance();
    await minterContract.withdraw();
    // Some ETH is lost from withdraw contract interaction.
    expect(
      (await signer.getBalance())
        .sub(signerBalance)
        .gte(ethers.utils.parseEther('0.19'))
    ).to.be.true;
  });
});
