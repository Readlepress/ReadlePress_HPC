import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL || 'redis://:dev_redis_password@localhost:6379');

redis.on('error', (err) => {
  console.error('Redis connection error:', err.message);
});

export default redis;
