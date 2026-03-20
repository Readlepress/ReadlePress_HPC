declare module 'ethers' {
  export class JsonRpcProvider {
    constructor(url: string);
    getTransaction(hash: string): Promise<TransactionResponse | null>;
    getBlock(blockNumber: number): Promise<Block | null>;
    getBlockNumber(): Promise<number>;
  }
  export class Wallet {
    constructor(privateKey: string, provider: JsonRpcProvider);
    address: string;
    sendTransaction(tx: { to: string; value: number; data: string }): Promise<TransactionResponse>;
  }
  interface TransactionResponse {
    hash: string;
    from: string;
    data: string;
    wait(): Promise<TransactionReceipt | null>;
  }
  interface TransactionReceipt {
    blockNumber: number;
  }
  interface Block {
    timestamp: number;
  }
}
