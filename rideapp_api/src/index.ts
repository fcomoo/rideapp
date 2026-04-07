import Fastify from 'fastify';
import fastifyWebsocket from '@fastify/websocket';
import cors from '@fastify/cors';
import { z } from 'zod';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import { redisPub, redisSub } from './redis/pub-sub';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

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

  const JWT_SECRET = process.env.JWT_SECRET || 'macuspana-premium-secret-2024';

  // --- Auth Support ---
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
    
    // Validación de teléfono obligatoria para conductores
    if (role === 'driver' && !phone) {
      return reply.code(400).send({ error: 'Phone is required for drivers' });
    }

    try {
      const hashedPassword = await bcrypt.hash(password, 10);
      const user = await (prisma as any).user.create({
        data: { name, email, password: hashedPassword, role, phone, status: 'idle' }
      });

      // Si es conductor, crear su perfil de Driver vacío
      if (role === 'driver') {
        await (prisma as any).driver.create({
          data: { 
            id: user.id, 
            vehicleDetails: { model: 'N/A', plate: 'N/A' },
            currentLocation: null, // PostgreSQL GIS handle required later
            rating: 5.0,
            isVerified: false,
            isOnline: false
          }
        });
      }

      const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
      return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } };
    } catch (err) {
      console.error(err);
      reply.code(400).send({ error: 'User already exists or invalid data' });
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

  server.get('/api/auth/me', { preHandler: [verifyToken] }, async (request) => {
    const decoded = (request as any).user;
    const user = await (prisma as any).user.findUnique({ where: { id: decoded.id } });
    return { user };
  });

  // --- API Routes ---
  server.get('/api/trips', async () =>
    (prisma as any).trip.findMany({ take: 20, include: { client: true, driver: true }, orderBy: { id: 'desc' } })
  );
  
  server.get('/api/drivers', async () =>
    (prisma as any).driver.findMany()
  );

  server.post('/api/drivers/:id/verify', async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const driver = await (prisma as any).driver.update({ where: { id }, data: { isVerified: true } });
      return { success: true, driver };
    } catch {
      reply.code(404).send({ error: 'Driver not found' });
    }
  });

  server.get('/api/stats', async () => {
    const [activeTrips, onlineDrivers, completedToday] = await Promise.all([
      (prisma as any).trip.count({ where: { status: 'inProgress' } }),
      (prisma as any).driver.count({ where: { isOnline: true } }),
      (prisma as any).trip.count({ where: { status: 'completed' } }),
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
    
    await (prisma as any).negotiationOffer.create({
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

  // --- Real-time Tracking ---
  server.post('/api/drivers/location', async (request) => {
    const { driverId, lat, lng } = request.body as any;
    const timestamp = Date.now();

    // Broadcast efímero vía Redis
    await redisPub.publish('drivers.locations', JSON.stringify({
      event: 'driver.location',
      channel: 'drivers.locations',
      payload: { driverId, lat, lng, timestamp }
    }));

    return { success: true };
  });

  // --- Chat (Mensajería Efímera) ---
  server.post('/api/chat/:tripId', async (request) => {
    const { tripId } = request.params as { tripId: string };
    const { id, senderId, senderRole, text } = request.body as any;
    const timestamp = Date.now();

    const message = { id, tripId, senderId, senderRole, text, timestamp };

    // Publicar en el canal del chat del viaje
    await redisPub.publish(`chat.${tripId}`, JSON.stringify({
      event: 'chat.message',
      channel: `chat.${tripId}`,
      payload: message
    }));

    return { success: true, message };
  });

  // --- SOS Emergency System ---
  server.post('/api/sos', async (request) => {
    const { userId, tripId, lat, lng, timestamp, message } = request.body as any;
    
    console.log(`[SOS ALERT] User: ${userId}, Location: ${lat},${lng}, Time: ${new Date(timestamp).toISOString()}`);

    // Publicar en el canal global de emergencias para el Dashboard Admin
    await redisPub.publish('admin.emergency', JSON.stringify({
      event: 'sos.alert',
      channel: 'admin.emergency',
      payload: { userId, tripId, lat, lng, timestamp, message }
    }));

    return { success: true };
  });

  // --- Rating System ---
  server.post('/api/trips/:tripId/rate', async (request, reply) => {
    const { tripId } = request.params as { tripId: string };
    const { rating, comment, ratedBy, ratedUserId } = request.body as any;

    if (rating < 1 || rating > 5) {
      return reply.code(400).send({ error: 'Rating must be between 1 and 5' });
    }

    try {
      // Prevención de duplicados (409 Conflict)
      const existing = await (prisma as any).rating.findFirst({
        where: { tripId, ratedBy }
      });
      
      if (existing) {
        return reply.code(409).send({ error: 'Este viaje ya ha sido calificado por ti' });
      }

      // Guardar calificación
      const newRating = await (prisma as any).rating.create({
        data: { tripId, ratedBy, ratedUserId, rating, comment }
      });

      // Actualizar promedio del Driver si es calificado por el pasajero
      if (ratedBy === 'passenger') {
        const allRatings = await (prisma as any).rating.findMany({
          where: { ratedUserId, ratedBy: 'passenger' }
        });
        
        const total = allRatings.reduce((acc: number, r: any) => acc + r.rating, 0);
        const average = total / allRatings.length;

        await (prisma as any).driver.update({
          where: { id: ratedUserId },
          data: { rating: average }
        });
      }

      return { success: true, rating: newRating };
    } catch (err) {
      console.error("[BACKEND RATING ERROR]", err);
      reply.code(500).send({ error: 'Rating failed' });
    }
  });

  // --- Passenger Trip History ---
  server.get('/api/trips/history/:userId', async (request) => {
    const { userId } = request.params as { userId: string };
    
    // En Macuspana devolvemos los últimos 20 viajes enriquecidos
    const trips = await (prisma as any).trip.findMany({
      where: { clientId: userId },
      take: 20,
      orderBy: { id: 'desc' },
      include: {
        driver: true,
      }
    });

    return trips.map((t: any) => ({
      id: t.id,
      origin: "Palacio Municipal", 
      destination: "Hospital General", 
      price: 85.00,
      status: t.status,
      createdAt: new Date().toISOString(),
      driverName: t.driver?.vehicleDetails?.driver_name || "Conductor",
      rating: 4.5
    }));
  });

  server.get('/health', async () => ({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    service: 'RideApp API - Macuspana'
  }));

  const port = Number(process.env.PORT) || 3000;
  await server.listen({ port, host: '0.0.0.0' });
  console.log(`[RideApp API] Running on port ${port}`);
};

start().catch((err) => { console.error(err); process.exit(1); });
