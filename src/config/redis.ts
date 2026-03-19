import Redis from 'ioredis';

const redisUrl = process.env.REDIS_URL;

let redis: Redis;

if (redisUrl) {
  redis = new Redis(redisUrl);
  redis.on('error', (err) => {
    console.error('Redis connection error:', err.message);
  });
} else {
  // Create a mock Redis client for development without Redis
  redis = new Proxy({} as Redis, {
    get(_target, prop) {
      if (prop === 'on' || prop === 'once' || prop === 'removeListener') {
        return () => {};
      }
      if (prop === 'exists' || prop === 'get' || prop === 'del') {
        return async () => null;
      }
      if (prop === 'set' || prop === 'setex' || prop === 'incr') {
        return async () => 'OK';
      }
      if (prop === 'status') {
        return 'ready';
      }
      return async () => null;
    },
  });
  console.log('Redis not configured — running without Redis (OTP cooldowns and rate limiting disabled)');
}

export default redis;
