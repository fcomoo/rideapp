import Redis from 'ioredis';
import dotenv from 'dotenv';
import { EventEmitter } from 'events';

dotenv.config();

const REDIS_URL = process.env.REDIS_URL;

class MockRedis extends EventEmitter {
  constructor(name: string) {
    super();
    console.warn(`[Redis ${name}] Running in OFFLINE/MOCK mode. Real-time events will not propagate.`);
  }

  async publish(channel: string, message: string) {
    // console.log(`[MockRedis Publish] ${channel}: ${message}`);
    return 0;
  }

  async subscribe(channel: string) {
    // console.log(`[MockRedis Subscribe] ${channel}`);
    return 0;
  }

  async unsubscribe(channel: string) {
    // console.log(`[MockRedis Unsubscribe] ${channel}`);
    return 0;
  }

  setMaxListeners(n: number) {
    return super.setMaxListeners(n);
  }

  // Simular desconexión/error para pruebas si es necesario
  quit() { return Promise.resolve('OK'); }
  disconnect() {}
}

const createRedisClient = (name: string): any => {
  if (!REDIS_URL) {
    return new MockRedis(name);
  }

  const client = new Redis(REDIS_URL, {
    maxRetriesPerRequest: null,
    lazyConnect: true, // Importante para no bloquear el arranque
    retryStrategy: (times) => {
      if (times > 3) {
        console.error(`[Redis ${name}] CRITICAL: Connection failed after ${times} attempts. Switching to Mock.`);
        return null; // Detener reintentos nativos de ioredis
      }
      const delay = 2000;
      console.log(`[Redis ${name}] Reconnecting in ${delay}ms (Attempt ${times}/3)...`);
      return delay;
    },
  });

  client.on('error', (err) => {
    console.error(`[Redis ${name}] Connection Error:`, err.message);
    // No dejamos que el error tire el proceso
  });

  return client;
};

// Instancias iniciales
export let redisPub = createRedisClient('Publisher');
export let redisSub = createRedisClient('Subscriber');

// Función para verificar si estamos en modo mock
export const isRedisOffline = () => {
  return !REDIS_URL || redisPub instanceof MockRedis;
};

export const publishEvent = async (channel: string, event: string, payload: any) => {
  try {
    const message = JSON.stringify({ event, channel, payload });
    await redisPub.publish(channel, message);
  } catch (err) {
    console.error('[Redis Publish] Failed:', err);
  }
};

export const subscribeToChannel = (channel: string, callback: (message: string) => void) => {
  try {
    redisSub.subscribe(channel);
    redisSub.on('message', (chan: string, msg: string) => {
      if (chan === channel) {
        callback(msg);
      }
    });
  } catch (err) {
    console.error('[Redis Subscribe] Failed:', err);
  }
};
