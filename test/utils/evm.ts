import { ethers, network } from "hardhat";
import { BigNumber } from "ethers";

export async function getCurrentTime(){
    return (
      await ethers.provider.getBlock(await ethers.provider.getBlockNumber())
    ).timestamp;
}

export async function evm_increaseTime(seconds : number){
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}

export async function evm_takeSnap(){
    return (await network.provider.request({
      method: "evm_snapshot",
      params: [],
    }));
}
  
export async function evm_restoreSnap(id : string){
    await network.provider.request({
      method: "evm_revert",
      params: [id],
    });
}

export async function setBalance( address : string, balance : BigNumber){
    await network.provider.send("hardhat_setBalance", [
        address,
        balance.toHexString().replace("0x0", "0x"),
      ]);
}
