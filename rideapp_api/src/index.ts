import Fastify from 'fastify';
import fastifyWebsocket from '@fastify/websocket';
import cors from '@fastify/cors';
import { z } from 'zod';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import { redisPub, redisSub } from './redis/pub-sub';

dotenv.config();
const prisma = new PrismaClient();
const server = Fastify();
const MessageSchema = z.object({
  event: z.string(),
  channel: z.string(),
  payload: z.record(z.unknown()),
});

const start = async () => {
  await server.register(cors, { origin: 'http://localhost:3001' });
  await server.register(fastifyWebsocket);

  // --- WebSockets ---
  server.get('/ws', { websocket: true }, (connection, req) => {
    const query = req.query as { channel?: string };
    const subscriptionChannel = query.channel;
    if (!subscriptionChannel) {
      connection.socket.close(1008, 'channel required');
      return;
    }
    console.log(`[WS] Client connected: ${subscriptionChannel}`);
    redisSub.subscribe(subscriptionChannel);
    const redisMessageListener = (chan: string, message: string) => {
      if (chan === subscriptionChannel) connection.socket.send(message);
    };
    redisSub.on('message', redisMessageListener);
    connection.socket.on('message', async (rawData: Buffer | string) => {
      try {
        const parsed = JSON.parse(rawData.toString());
        const validated = MessageSchema.safeParse(parsed);
        if (!validated.success) {
          connection.socket.close(1008, 'Invalid');
          return;
        }
        const { event, channel, payload } = validated.data;
        console.log(`[WS] Received [${event}] on [${channel}]`);
        await redisPub.publish(channel, JSON.stringify({ event, channel, payload }));
      } catch (err) {
        console.error('[WS] Error:', err);
      }
    });
    connection.socket.on('close', () => {
      console.log(`[WS] Disconnected: ${subscriptionChannel}`);
      redisSub.removeListener('message', redisMessageListener);
      if (redisSub.listenerCount('message') === 0) {
        redisSub.unsubscribe(subscriptionChannel);
      }
    });
    connection.socket.on('error', (err: Error) => {
      console.error('[WS] Socket error:', err);
    });
  });

  // --- API Routes ---
  server.get('/api/trips', async () =>
    prisma.trip.findMany({ take: 20, include: { client: true, driver: true }, orderBy: { id: 'desc' } })
  );
  
  server.get('/api/drivers', async () =>
    prisma.driver.findMany({ orderBy: { isVerified: 'asc' } })
  );

  server.post('/api/drivers/:id/verify', async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const driver = await prisma.driver.update({ where: { id }, data: { isVerified: true } });
      return { success: true, driver };
    } catch {
      reply.code(404).send({ error: 'Driver not found' });
    }
  });

  server.get('/api/stats', async () => {
    const [activeTrips, onlineDrivers, completedToday] = await Promise.all([
      prisma.trip.count({ where: { status: 'inProgress' } }),
      prisma.driver.count({ where: { isOnline: true } }),
      prisma.trip.count({ where: { status: 'completed' } }),
    ]);
    return { activeTrips, onlineDrivers, completedToday };
  });

  // --- Negociación (Modo InDriver) ---
  server.post('/api/negotiate', async (request) => {
    const { tripId, clientId, origin, destination, offeredPrice } = request.body as any;
    await redisPub.publish('search.broadcast', JSON.stringify({
      event: 'negotiation.broadcast', channel: 'search.broadcast',
      payload: { tripId, clientId, origin, destination, offeredPrice }
    }));
    return { success: true };
  });

  server.post('/api/negotiate/counter', async (request) => {
    const { tripId, driverId, counterPrice, offeredPrice } = request.body as any;
    // Exclusividad: Un conductor solo una contraoferta activa
    await prisma.$executeRawUnsafe(`
      UPDATE "NegotiationOffer" SET status = 'cancelled' 
      WHERE "driverId" = '${driverId}' AND status = 'counter'
    `);
    
    await prisma.negotiationOffer.create({
      data: { tripId, driverId, offeredPrice, counterPrice, status: 'counter' }
    });
    
    await redisPub.publish(`trip.${tripId}`, JSON.stringify({
      event: 'negotiation.counter', channel: `trip.${tripId}`,
      payload: { tripId, driverId, counterPrice }
    }));
    return { success: true };
  });

  server.post('/api/negotiate/accept', async (request) => {
    const { tripId, driverId, clientId } = request.body as any;
    const trip = await prisma.trip.create({
      data: { id: tripId, clientId, driverId, status: 'accepted' }
    });
    
    await prisma.$executeRawUnsafe(`
      UPDATE "NegotiationOffer" SET status = 'accepted' 
      WHERE "tripId" = '${tripId}' AND "driverId" = '${driverId}' AND status = 'counter'
    `);

    await redisPub.publish('search.broadcast', JSON.stringify({
      event: 'offer.closed', channel: 'search.broadcast',
      payload: { tripId, driverId }
    }));
    return { success: true, trip };
  });

  const port = Number(process.env.PORT) || 3000;
  await server.listen({ port, host: '0.0.0.0' });
  console.log(`[RideApp API] Running on port ${port}`);
};

start().catch((err) => { console.error(err); process.exit(1); });
