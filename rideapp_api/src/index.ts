import Fastify from 'fastify';
import fastifyWebsocket from '@fastify/websocket';
import { z } from 'zod';
import dotenv from 'dotenv';
import { redisPub, redisSub } from './redis/pub-sub';

dotenv.config();

const server = Fastify();
server.register(fastifyWebsocket);

// Esquema de validación para mensajes Antigravity
const MessageSchema = z.object({
  event: z.string(),
  channel: z.string(),
  payload: z.record(z.unknown()),
});

server.register(async (fastify) => {
  fastify.get('/ws', { websocket: true }, (connection, req) => {
    const query = req.query as { channel?: string };
    const subscriptionChannel = query.channel;

    if (!subscriptionChannel) {
      console.error('[WS] Handshake failed: No channel in query params.');
      connection.socket.close(1008, 'Policy Violation: channel parameter required');
      return;
    }

    console.log(`[WS] Client connected. Subscribing to Redis: ${subscriptionChannel}`);

    // Suscribir el cliente compartido de Redis al canal solicitado
    redisSub.subscribe(subscriptionChannel);

    // Listener de Redis para reenviar mensajes al Socket
    const redisMessageListener = (chan: string, message: string) => {
      if (chan === subscriptionChannel) {
        connection.socket.send(message);
      }
    };

    redisSub.on('message', redisMessageListener);

    // Manejar mensajes entrantes del cliente Flutter (Mutaciones/Eventos)
    connection.socket.on('message', async (rawData: Buffer | string) => {
      try {
        const parsed = JSON.parse(rawData.toString());
        const validated = MessageSchema.safeParse(parsed);

        if (!validated.success) {
          console.error('[WS] Validation Error:', validated.error.format());
          connection.socket.close(1008, 'Policy Violation: Invalid Antigravity message');
          return;
        }

        const { event, channel, payload } = validated.data;
        console.log(`[WS] Received [${event}] on channel [${channel}]`);

        // Broadcaster: Publicar en Redis para que llegue a todos los interesados
        await redisPub.publish(channel, JSON.stringify({ event, channel, payload }));

      } catch (err) {
        console.error('[WS] Critical Parse Error:', err);
        connection.socket.close(1008, 'Internal Server Error');
      }
    });

    // Limpieza al cerrar la conexión
    connection.socket.on('close', () => {
      console.log(`[WS] Client disconnected from [${subscriptionChannel}]`);
      redisSub.removeListener('message', redisMessageListener);
      
      // Si no hay más listeners para este canal en este proceso, podríamos desuscribirnos
      if (redisSub.listenerCount('message') === 0) {
        redisSub.unsubscribe(subscriptionChannel);
      }
    });

    connection.socket.on('error', (err: Error) => {
      console.error('[WS] Socket Error:', err);
    });
  });
});

const start = async () => {
  try {
    const port = Number(process.env.PORT) || 3000;
    await server.listen({ port, host: '0.0.0.0' });
    console.log(`[RideApp API] Antigravity Bridge running on port ${port}`);
  } catch (err: unknown) {
    server.log.error(err as Error);
    process.exit(1);
  }
};

start();
