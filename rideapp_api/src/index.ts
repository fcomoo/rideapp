import Fastify from 'fastify';
import fastifyWebsocket from '@fastify/websocket';
import cors from '@fastify/cors';
import { z } from 'zod';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { exec } from 'child_process';
import { promisify } from 'util';
import { authRoutes } from './routes/auth';
import { negotiateRoutes } from './routes/negotiate';
import { uploadRoutes } from './routes/upload';
import fastifyStatic from '@fastify/static';
import fastifyMultipart from '@fastify/multipart';
import { join } from 'path';

const execAsync = promisify(exec);
dotenv.config();

// Estados de conexión para Healthcheck
let dbReady = false;
let redisReady = false;
let migrationReady = false;
let redisPub: any = null;
let redisSub: any = null;

const prisma = new PrismaClient();
const server = Fastify();

const MessageSchema = z.object({
  event: z.string(),
  channel: z.string(),
  payload: z.record(z.unknown()),
});

const start = async () => {
  console.log('[BOOT] Starting RideApp API - Macuspana...');

  // 1. Configuración básica de Fastify
  await server.register(cors, { origin: '*' });
  await server.register(fastifyWebsocket);
  await server.register(authRoutes);
  await server.register(negotiateRoutes);
  await server.register(uploadRoutes);

  await server.register(fastifyMultipart);
  await server.register(fastifyStatic, {
    root: join(process.cwd(), 'uploads'),
    prefix: '/uploads/',
  });

  // --- Health Check (Resiliente) ---
  server.get('/health', async () => ({ 
    status: 'ok', 
    db: dbReady ? 'connected' : 'connecting',
    redis: redisReady ? 'connected' : 'connecting',
    migrations: migrationReady ? 'done' : 'pending',
    timestamp: new Date().toISOString(),
    service: 'RideApp API - Macuspana'
  }));

  // --- WebSockets ---
  server.get('/ws', { websocket: true }, (connection, req) => {
    const query = req.query as { channel?: string };
    const subscriptionChannel = query.channel;
    if (!subscriptionChannel) {
      connection.socket.close(1008, 'channel required');
      return;
    }
    
    const redisMessageListener = (chan: string, message: string) => {
      if (chan === subscriptionChannel) connection.socket.send(message);
    };

    if (redisReady && redisSub) {
      redisSub.subscribe(subscriptionChannel);
      redisSub.on('message', redisMessageListener);
    }
    
    connection.socket.on('message', async (rawData: Buffer | string) => {
      try {
        const parsed = JSON.parse(rawData.toString());
        const validated = MessageSchema.safeParse(parsed);
        if (!validated.success) {
          connection.socket.close(1008, 'Invalid');
          return;
        }
        const { event, channel, payload } = validated.data;

        if (redisReady && redisPub) {
          // Publicar en el canal original
          await redisPub.publish(channel, JSON.stringify({ event, channel, payload }));

          // Si es ubicación de conductor, retransmitir al canal global
          // que escuchan todos los pasajeros
          if (event === 'driver.location') {
            await redisPub.publish(
              'drivers.locations',
              JSON.stringify({ event, channel: 'drivers.locations', payload })
            );
          }

          // Si es trip.requested, retransmitir al canal global de conductores
          if (event === 'trip.requested') {
            await redisPub.publish(
              'trips.requests',
              JSON.stringify({ event, channel: 'trips.requests', payload })
            );
          }
        }
      } catch (err) {
        console.error('[WS] Error:', err);
      }
    });

    connection.socket.on('close', () => {
      if (redisReady && redisSub) {
        redisSub.removeListener('message', redisMessageListener);
        if (redisSub.listenerCount('message') === 0) {
          redisSub.unsubscribe(subscriptionChannel);
        }
      }
    });
  });

  const JWT_SECRET = process.env.JWT_SECRET || 'macuspana-premium-secret-2024';

  // --- API Routes ---
  server.get('/api/trips', async () => (prisma as any).trip.findMany({ take: 20, include: { client: true, driver: true }, orderBy: { id: 'desc' } }));

  // 2. AMARRE INMEDIATO DE PUERTO (Eager Port Binding)
  const port = Number(process.env.PORT) || 3000;
  try {
    await server.listen({ port, host: '0.0.0.0' });
    console.log(`[BOOT] API ONLINE: Listening on port ${port}`);
  } catch (err) {
    console.error('[CRITICAL] Port bind failed:', err);
    process.exit(1);
  }

  // 3. Tareas asíncronas post-arranque (Servicios)
  (async () => {
    try {
      console.log('[BOOT] Connecting to Database client...');
      await prisma.$connect();
      dbReady = true;
      console.log('[BOOT] Database client ready.');
    } catch (err: any) {
      console.error('[BOOT] Database client failed:', err.message);
    }

    try {
      console.log('[BOOT] Lazy loading Redis...');
      const redisModule = await import('./redis/pub-sub');
      redisPub = redisModule.redisPub;
      redisSub = redisModule.redisSub;
      
      // Fix memory leak: Increase max listeners and ensure it persists
      redisSub.setMaxListeners(50);
      
      // Detectar si es Mock o Redis real por constructor name
      if (redisSub.constructor.name === 'MockRedis') {
          console.log('[REDIS] Running in offline mode (Mock). REST API remains fully operational.');
          redisReady = false;
      } else {
          // Es ioredis real, conectar explícitamente
          redisPub.connect().catch(() => {});
          redisSub.connect().catch(() => {});
          redisSub.on('connect', () => {
             redisSub.setMaxListeners(50);
             redisReady = true;
             console.log('[REDIS] Connected and MaxListeners set to 50');
          });
          redisPub.on('connect', () => {
             redisPub.setMaxListeners(50);
             console.log('[REDIS] Publisher connected');
          });
      }

      console.log('[BOOT] Redis phase completed.');
    } catch (err: any) {
      console.error('[BOOT] Redis critical failure (Offline Mode activated):', err.message);
      redisReady = false; // El servidor sigue vivo gracias al try/catch
    }
  })();
};

start().catch((err) => {
  console.error('[CRITICAL] Startup crash:', err);
  process.exit(1);
});
// deploy miércoles,  8 de abril de 2026, 09:51:52 CST
// cache bust miércoles,  8 de abril de 2026, 11:52:53 CST
