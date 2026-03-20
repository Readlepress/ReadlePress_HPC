import * as crypto from 'crypto';
import { query } from '../config/database';

export interface AnchorResult {
  transactionHash: string;
  blockNumber: number;
  chainName: string;
  verificationUrl: string;
}

export interface VerifyResult {
  verified: boolean;
  anchorData: Record<string, unknown> | null;
  blockTimestamp: string | null;
  confirmations: number;
}

function isMockMode(): boolean {
  return !process.env.BLOCKCHAIN_RPC_URL;
}

export async function anchorMerkleRoot(
  tenantId: string,
  yearSnapshotId: string,
  merkleRootHash: string
): Promise<AnchorResult> {
  if (!isMockMode()) {
    return anchorMerkleRootLive(tenantId, yearSnapshotId, merkleRootHash);
  }

  const timestamp = Date.now().toString();
  const transactionHash = '0x' + crypto
    .createHash('sha256')
    .update(merkleRootHash + timestamp)
    .digest('hex');
  const blockNumber = 10_000_000 + Math.floor(Math.random() * 1_000_000);
  const chainName = 'polygon-mock';
  const verificationUrl = `https://polygonscan.com/tx/${transactionHash}`;

  await query(
    `INSERT INTO blockchain_anchors
       (tenant_id, year_snapshot_id, merkle_root_hash, transaction_hash, block_number,
        chain_name, verification_url, anchored_at, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), 'CONFIRMED')`,
    [tenantId, yearSnapshotId, merkleRootHash, transactionHash, blockNumber, chainName, verificationUrl]
  );

  return { transactionHash, blockNumber, chainName, verificationUrl };
}

async function anchorMerkleRootLive(
  tenantId: string,
  yearSnapshotId: string,
  merkleRootHash: string
): Promise<AnchorResult> {
  const { JsonRpcProvider, Wallet } = await import('ethers');

  const provider = new JsonRpcProvider(process.env.BLOCKCHAIN_RPC_URL!);
  const wallet = new Wallet(process.env.BLOCKCHAIN_PRIVATE_KEY || '', provider);

  const dataHex = '0x' + Buffer.from(merkleRootHash, 'utf8').toString('hex');
  const tx = await wallet.sendTransaction({
    to: wallet.address,
    value: 0,
    data: dataHex,
  });
  const receipt = await tx.wait();

  const transactionHash = tx.hash;
  const blockNumber = receipt?.blockNumber ?? 0;
  const chainName = 'polygon';
  const verificationUrl = `https://polygonscan.com/tx/${transactionHash}`;

  await query(
    `INSERT INTO blockchain_anchors
       (tenant_id, year_snapshot_id, merkle_root_hash, transaction_hash, block_number,
        chain_name, verification_url, anchored_at, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), 'CONFIRMED')`,
    [tenantId, yearSnapshotId, merkleRootHash, transactionHash, blockNumber, chainName, verificationUrl]
  );

  return { transactionHash, blockNumber, chainName, verificationUrl };
}

export async function verifyBlockchainAnchor(transactionHash: string): Promise<VerifyResult> {
  if (!isMockMode()) {
    return verifyBlockchainAnchorLive(transactionHash);
  }

  const result = await query(
    `SELECT * FROM blockchain_anchors WHERE transaction_hash = $1`,
    [transactionHash]
  );

  if (result.rows.length === 0) {
    return { verified: false, anchorData: null, blockTimestamp: null, confirmations: 0 };
  }

  const row = result.rows[0];
  return {
    verified: true,
    anchorData: {
      tenantId: row.tenant_id,
      yearSnapshotId: row.year_snapshot_id,
      merkleRootHash: row.merkle_root_hash,
      chainName: row.chain_name,
      verificationUrl: row.verification_url,
    },
    blockTimestamp: row.anchored_at?.toISOString() ?? null,
    confirmations: 100,
  };
}

async function verifyBlockchainAnchorLive(transactionHash: string): Promise<VerifyResult> {
  const { JsonRpcProvider } = await import('ethers');

  const provider = new JsonRpcProvider(process.env.BLOCKCHAIN_RPC_URL!);
  const tx = await provider.getTransaction(transactionHash);

  if (!tx) {
    return { verified: false, anchorData: null, blockTimestamp: null, confirmations: 0 };
  }

  const receipt = await tx.wait();
  const block = receipt ? await provider.getBlock(receipt.blockNumber) : null;
  const currentBlock = await provider.getBlockNumber();

  return {
    verified: true,
    anchorData: {
      from: tx.from,
      blockNumber: receipt?.blockNumber ?? null,
      data: tx.data,
    },
    blockTimestamp: block ? new Date(block.timestamp * 1000).toISOString() : null,
    confirmations: receipt ? currentBlock - receipt.blockNumber : 0,
  };
}

export async function getAnchorHistory(tenantId: string) {
  const result = await query(
    `SELECT id, tenant_id, year_snapshot_id, merkle_root_hash, transaction_hash,
            block_number, chain_name, verification_url, anchored_at, status
     FROM blockchain_anchors
     WHERE tenant_id = $1
     ORDER BY anchored_at DESC`,
    [tenantId]
  );
  return result.rows;
}
