import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  anchorMerkleRoot,
  verifyBlockchainAnchor,
  getAnchorHistory,
} from '../services/blockchain.service';

export default async function blockchainRoutes(app: FastifyInstance) {
  app.post('/blockchain/anchor', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      yearSnapshotId: string;
      merkleRootHash: string;
    };

    const result = await anchorMerkleRoot(user.tenantId, body.yearSnapshotId, body.merkleRootHash);
    return reply.code(201).send(result);
  });

  app.get('/blockchain/verify/:transactionHash', async (request) => {
    const { transactionHash } = request.params as { transactionHash: string };
    return verifyBlockchainAnchor(transactionHash);
  });

  app.get('/blockchain/history', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const anchors = await getAnchorHistory(user.tenantId);
    return { anchors };
  });
}
