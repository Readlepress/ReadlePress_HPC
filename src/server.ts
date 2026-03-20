import Fastify from 'fastify';
import fastifyJwt from '@fastify/jwt';
import fastifyCors from '@fastify/cors';
import fastifyRateLimit from '@fastify/rate-limit';
import fastifyWebsocket from '@fastify/websocket';

import authRoutes from './routes/auth.routes';
import consentRoutes from './routes/consent.routes';
import studentRoutes from './routes/student.routes';
import academicYearRoutes from './routes/academic-year.routes';
import competencyRoutes from './routes/competency.routes';
import localizationRoutes from './routes/localization.routes';
import evidenceRoutes from './routes/evidence.routes';
import evidenceExtendedRoutes from './routes/evidence-extended.routes';
import captureRoutes from './routes/capture.routes';
import rubricRoutes from './routes/rubric.routes';
import masteryRoutes from './routes/mastery.routes';
import feedbackRoutes from './routes/feedback.routes';
import interventionRoutes from './routes/intervention.routes';
import overlayRoutes from './routes/overlay.routes';
import uiSchemaRoutes from './routes/ui-schema.routes';
import creditRoutes from './routes/credit.routes';
import exportRoutes from './routes/export.routes';
import governanceRoutes from './routes/governance.routes';
import aiRoutes from './routes/ai.routes';
import districtRoutes from './routes/district.routes';
import businessRoutes from './routes/business.routes';
import sqaaRoutes from './routes/sqaa.routes';
import complianceRoutes from './routes/compliance.routes';
import portabilityRoutes from './routes/portability.routes';
import cpdRoutes from './routes/cpd.routes';
import communityRoutes from './routes/community.routes';
import blockchainRoutes from './routes/blockchain.routes';
import realtimeRoutes from './routes/realtime.routes';
import nlpRoutes from './routes/nlp.routes';
import visionRoutes from './routes/vision.routes';
import simulationRoutes from './routes/simulation.routes';
import autoSqaaRoutes from './routes/auto-sqaa.routes';
import recommendationRoutes from './routes/recommendation.routes';

function getLoggerConfig() {
  try {
    if (process.env.NODE_ENV === 'development') {
      require.resolve('pino-pretty');
      return {
        level: process.env.LOG_LEVEL || 'info',
        transport: { target: 'pino-pretty' },
      };
    }
  } catch {
    // pino-pretty not available
  }
  return { level: process.env.LOG_LEVEL || 'info' };
}

const app = Fastify({ logger: getLoggerConfig() });

async function buildApp() {
  await app.register(fastifyCors, { origin: true });

  await app.register(fastifyJwt, {
    secret: process.env.JWT_SECRET || 'dev_jwt_secret_256bit_minimum_key_for_development_only',
  });

  await app.register(fastifyRateLimit, {
    max: 100,
    timeWindow: '1 minute',
  });

  await app.register(fastifyWebsocket);

  // Health check
  app.get('/health', async () => ({ status: 'ok', timestamp: new Date().toISOString() }));

  // API v1 routes
  await app.register(async (v1) => {
    await v1.register(authRoutes);
    await v1.register(consentRoutes);
    await v1.register(studentRoutes);
    await v1.register(academicYearRoutes);
    await v1.register(competencyRoutes);
    await v1.register(localizationRoutes);
    await v1.register(evidenceRoutes);
    await v1.register(evidenceExtendedRoutes);
    await v1.register(captureRoutes);
    await v1.register(rubricRoutes);
    await v1.register(masteryRoutes);
    await v1.register(feedbackRoutes);
    await v1.register(interventionRoutes);
    await v1.register(overlayRoutes);
    await v1.register(uiSchemaRoutes);
    await v1.register(creditRoutes);
    await v1.register(exportRoutes);
    await v1.register(governanceRoutes);
    await v1.register(aiRoutes);
    await v1.register(districtRoutes);
    await v1.register(businessRoutes);
    await v1.register(sqaaRoutes);
    await v1.register(complianceRoutes);
    await v1.register(portabilityRoutes);
    await v1.register(cpdRoutes);
    await v1.register(communityRoutes);
    await v1.register(nlpRoutes);
    await v1.register(visionRoutes);
    await v1.register(simulationRoutes);
    await v1.register(autoSqaaRoutes);
    await v1.register(recommendationRoutes);
    await v1.register(blockchainRoutes);
    await v1.register(realtimeRoutes);
  }, { prefix: '/api/v1' });

  return app;
}

async function start() {
  try {
    const server = await buildApp();
    const port = parseInt(process.env.PORT || '3000');
    const host = process.env.HOST || '0.0.0.0';

    await server.listen({ port, host });
    console.log(`ReadlePress API server running on ${host}:${port}`);
    console.log(`  Health: http://localhost:${port}/health`);
    console.log(`  API:    http://localhost:${port}/api/v1/`);
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
});

process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
});

start();

export { buildApp };
