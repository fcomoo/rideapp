import Redis from 'ioredis';
import dotenv from 'dotenv';

dotenv.config();

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

const createRedisClient = (name: string) => {
  let retryCount = 0;

  const client = new Redis(REDIS_URL, {
    maxRetriesPerRequest: null,
    retryStrategy: (times) => {
      if (times > 3) {
        console.error(`[Redis ${name}] CRITICAL: Reconnection failed after ${times} attempts.`);
        return null; // Stop retrying
      }
      const delay = 5000;
      console.log(`[Redis ${name}] Retrying connection in ${delay}ms (Attempt ${times}/3)...`);
      return delay;
    },
  });

  client.on('connect', () => {
    console.log(`[Redis ${name}] Connected successfully.`);
    retryCount = 0;
  });

  client.on('error', (err) => {
    console.error(`[Redis ${name}] Error:`, err.message);
  });

  return client;
};

// Necesitamos instancias separadas para publicador y suscriptor
export const redisPub = createRedisClient('Publisher');
export const redisSub = createRedisClient('Subscriber');

export const publishEvent = async (channel: string, event: string, payload: any) => {
  const message = JSON.stringify({ event, channel, payload });
  await redisPub.publish(channel, message);
};

export const subscribeToChannel = (channel: string, callback: (message: string) => void) => {
  redisSub.subscribe(channel);
  redisSub.on('message', (chan, msg) => {
    if (chan === channel) {
      callback(msg);
    }
  });
};
