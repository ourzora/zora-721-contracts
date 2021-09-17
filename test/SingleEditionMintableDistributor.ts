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

  it("purchases a edition", async () => {
    await dynamicSketch.createEdition(
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

    const editionResult = await dynamicSketch.getEditionAtId(0);
    const minterContract = (await ethers.getContractAt(
      "SingleEditionMintable",
      editionResult
    )) as SingleEditionMintable;

    

    expect(await minterContract.name()).to.be.equal("Testing Token");
    expect(await minterContract.symbol()).to.be.equal("TEST");

    // expect(await minterContract.setApprovedMinter())
  });
});
