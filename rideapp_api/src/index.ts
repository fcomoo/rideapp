import Fastify from 'fastify';
import fastifyWebsocket from '@fastify/websocket';
import cors from '@fastify/cors';
import { z } from 'zod';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

dotenv.config();

// Estados de conexión para Healthcheck
let dbReady = false;
let redisReady = false;
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

  // --- Health Check (Resiliente) ---
  server.get('/health', async () => ({ 
    status: 'ok', 
    db: dbReady ? 'connected' : 'connecting',
    redis: redisReady ? 'connected' : 'connecting',
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
    console.log(`[WS] Client connected: ${subscriptionChannel}`);
    
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
          await redisPub.publish(channel, JSON.stringify({ event, channel, payload }));
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

  const verifyToken = async (request: any, reply: any) => {
    try {
      const auth = request.headers.authorization;
      if (!auth) throw new Error('No token');
      const token = auth.split(' ')[1];
      const decoded = jwt.verify(token, JWT_SECRET) as any;
      request.user = decoded;
    } catch (err) {
      reply.code(401).send({ error: 'Unauthorized' });
    }
  };

  // --- Auth Routes ---
  server.post('/api/auth/register', async (request, reply) => {
    const { name, email, password, role, phone } = request.body as any;
    if (role === 'driver' && !phone) return reply.code(400).send({ error: 'Phone required' });
    try {
      const hashedPassword = await bcrypt.hash(password, 10);
      const user = await (prisma as any).user.create({
        data: { name, email, password: hashedPassword, role, phone, status: 'idle' }
      });
      const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
      return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } };
    } catch (err) {
      reply.code(400).send({ error: 'Registration failed' });
    }
  });

  server.post('/api/auth/login', async (request, reply) => {
    const { email, password } = request.body as any;
    const user = await (prisma as any).user.findUnique({ where: { email } });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return reply.code(401).send({ error: 'Invalid credentials' });
    }
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } };
  });

  // --- API Routes ---
  server.get('/api/trips', async () => (prisma as any).trip.findMany({ take: 20, include: { client: true, driver: true }, orderBy: { id: 'desc' } }));

  // 2. AMARRE INMEDIATO DE PUERTO (Eager Port Binding)
  const port = Number(process.env.PORT) || 3000;
  try {
    console.log(`[BOOT] Attempting port bind on ${port}...`);
    await server.listen({ port, host: '0.0.0.0' });
    console.log(`[BOOT] RideApp API SUCCESS: Listening on port ${port}`);
  } catch (err) {
    console.error('[CRITICAL] Port bind failed:', err);
    process.exit(1);
  }

  // 3. LAZY LOADING de servicios pesados (Post-Bind)
  (async () => {
    try {
      console.log('[BOOT] Connecting to Database...');
      await prisma.$connect();
      dbReady = true;
      console.log('[BOOT] Database connected.');
    } catch (err) {
      console.error('[BOOT] Database failed:', err.message);
    }

    try {
      console.log('[BOOT] Lazy loading Redis modules...');
      const redisModule = await import('./redis/pub-sub');
      redisPub = redisModule.redisPub;
      redisSub = redisModule.redisSub;
      redisReady = true;
      console.log('[BOOT] Redis initialized successfully.');
    } catch (err) {
      console.error('[BOOT] Redis lazy load failed:', err.message);
    }
  })();
};

start().catch((err) => {
  console.error('[CRITICAL] Global startup crash:', err);
  process.exit(1);
});
