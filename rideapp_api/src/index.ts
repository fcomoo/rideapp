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

  server.register(async (fastify) => {
    fastify.get('/ws', { websocket: true }, (connection, req) => {
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

    fastify.get('/api/trips', async () =>
      prisma.trip.findMany({ take: 20, include: { client: true, driver: true }, orderBy: { id: 'desc' } })
    );
    fastify.get('/api/drivers', async () =>
      prisma.driver.findMany({ orderBy: { isVerified: 'asc' } })
    );
    fastify.post('/api/drivers/:id/verify', async (request, reply) => {
      const { id } = request.params as { id: string };
      try {
        const driver = await prisma.driver.update({ where: { id }, data: { isVerified: true } });
        return { success: true, driver };
      } catch {
        reply.code(404).send({ error: 'Driver not found' });
      }
    });
    fastify.get('/api/stats', async () => {
      const [activeTrips, onlineDrivers, completedToday] = await Promise.all([
        prisma.trip.count({ where: { status: 'inProgress' } }),
        prisma.driver.count({ where: { isOnline: true } }),
        prisma.trip.count({ where: { status: 'completed' } }),
      ]);
      return { activeTrips, onlineDrivers, completedToday };
    });
  });

  const port = Number(process.env.PORT) || 3000;
  await server.listen({ port, host: '0.0.0.0' });
  console.log(`[RideApp API] Running on port ${port}`);
};

start().catch((err) => { console.error(err); process.exit(1); });
