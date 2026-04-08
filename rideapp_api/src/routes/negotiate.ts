import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';

const prisma = new PrismaClient();

const StartNegotiationSchema = z.object({
  tripId: z.string(),
  clientId: z.string(),
  origin: z.object({ lat: z.number(), lng: z.number() }),
  destination: z.object({ lat: z.number(), lng: z.number() }),
  offeredPrice: z.number(),
});

const CounterOfferSchema = z.object({
  tripId: z.string(),
  driverId: z.string(),
  counterPrice: z.number(),
  offeredPrice: z.number(),
});

const AcceptOfferSchema = z.object({
  tripId: z.string(),
  driverId: z.string(),
  clientId: z.string(),
  finalPrice: z.number(),
});

export async function negotiateRoutes(server: FastifyInstance) {
  // POST /api/negotiate — pasajero inicia negociación
  server.post('/api/negotiate', async (request, reply) => {
    const parsed = StartNegotiationSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Datos inválidos', details: parsed.error.issues });
    }
    const { tripId, offeredPrice } = parsed.data;
    try {
      const offer = await prisma.negotiationOffer.create({
        data: {
          tripId,
          driverId: 'pending',
          offeredPrice,
          status: 'pending',
        },
      });
      return reply.status(201).send({ offer });
    } catch (err: any) {
      console.error('[API] startNegotiation Error:', err);
      return reply.status(500).send({ error: 'Error al iniciar negociación' });
    }
  });

  // POST /api/negotiate/counter — conductor envía contraoferta
  server.post('/api/negotiate/counter', async (request, reply) => {
    const parsed = CounterOfferSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Datos inválidos' });
    }
    const { tripId, driverId, counterPrice, offeredPrice } = parsed.data;
    try {
      const offer = await prisma.negotiationOffer.create({
        data: {
          tripId,
          driverId,
          offeredPrice,
          counterPrice,
          status: 'counter',
        },
      });
      return reply.status(201).send({ offer });
    } catch (err: any) {
      console.error('[API] counterOffer Error:', err);
      return reply.status(500).send({ error: 'Error al enviar contraoferta' });
    }
  });

  // POST /api/negotiate/accept — pasajero acepta oferta
  server.post('/api/negotiate/accept', async (request, reply) => {
    const parsed = AcceptOfferSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Datos inválidos' });
    }
    const { tripId, driverId, finalPrice } = parsed.data;
    try {
      await prisma.negotiationOffer.updateMany({
        where: { tripId, driverId },
        data: { status: 'accepted' },
      });
      await (prisma as any).trip.update({
        where: { id: tripId },
        data: { driverId, status: 'accepted' },
      });
      return reply.send({ success: true, finalPrice });
    } catch (err: any) {
      console.error('[API] acceptOffer Error:', err);
      return reply.status(500).send({ error: 'Error al aceptar oferta' });
    }
  });
}
