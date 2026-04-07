import { PrismaClient } from '@prisma/client';
import WebSocket from 'ws';
import { v4 as uuidv4 } from 'uuid';
import axios from 'axios';

const prisma = new PrismaClient();
const WS_URL = 'ws://localhost:3000/ws';
const API_URL = 'http://localhost:3000/api';

async function main() {
  console.log('🚀 Iniciando Prueba de Flujo de Negociación (InDriver Mode)\n');

  const passengerUserId = uuidv4();
  const driverUserId = uuidv4();
  const driverId = uuidv4();
  const tripId = uuidv4();

  // --- 1. SETUP BD ---
  await prisma.user.create({ data: { id: passengerUserId, role: 'client', status: 'idle' } });
  await prisma.$executeRawUnsafe(`
    INSERT INTO "Driver" (id, "vehicleDetails", "currentLocation", rating, "isVerified", "isOnline")
    VALUES ('${driverId}', '{"driver_name": "Antigravity Pilot", "license_plate": "AG-2024", "model": "Tesla Model 3", "email": "pilot@rideapp.com"}', ST_SetSRID(ST_MakePoint(-99.1332, 19.4326), 4326), 4.8, true, true)
  `);
  console.log(`[DB] Pasajero y Conductor creados.\n`);

  // --- 2. PREPARAR ESCUCHAS ---
  const driverSocket = new WebSocket(`${WS_URL}?channel=search.broadcast`);
  const passengerSocket = new WebSocket(`${WS_URL}?channel=trip.${tripId}`);

  const waitForOpen = (socket: WebSocket): Promise<void> => 
    new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject('Timeout waiting for socket open'), 5000);
      socket.on('open', () => { clearTimeout(timeout); resolve(); });
    });

  const waitForEvent = (socket: WebSocket, eventType: string, timeoutMs: number = 10000): Promise<any> => {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(`Timeout esperando evento: ${eventType}`), timeoutMs);
      const listener = (data: any) => {
        const msg = JSON.parse(data.toString());
        if (msg.event === eventType) {
          clearTimeout(timeout);
          socket.removeListener('message', listener);
          resolve(msg);
        }
      };
      socket.on('message', listener);
    });
  };

  try {
    await Promise.all([waitForOpen(driverSocket), waitForOpen(passengerSocket)]);
    console.log('[Net] Sockets conectados y escuchando.\n');

    // --- 3. PASAJERO LANZA NEGOCIACIÓN ---
    console.log('[Passenger] Emitiendo negotiate ($85)...');
    
    // El conductor empieza a esperar la solicitud ANTES del post
    const broadcastPromise = waitForEvent(driverSocket, 'negotiation.broadcast');
    
    await axios.post(`${API_URL}/negotiate`, {
      tripId, clientId: passengerUserId, 
      origin: { lat: 19.4326, lng: -99.1332 },
      destination: { lat: 19.4284, lng: -99.1276 },
      offeredPrice: 85.00
    });

    const broadcastMsg = await broadcastPromise;
    console.log(`[Driver] ✅ Recibida solicitud broadcast para ${broadcastMsg.payload.tripId}`);

    // --- 4. CONDUCTOR LANZA CONTRAOFERTA ---
    console.log('[Driver] Emitiendo contraoferta ($90)...');
    
    // El pasajero empieza a esperar ANTES del post
    const counterPromise = waitForEvent(passengerSocket, 'negotiation.counter');

    await axios.post(`${API_URL}/negotiate/counter`, {
      tripId, driverId, offeredPrice: 85.00, counterPrice: 90.00
    });

    const counterMsg = await counterPromise;
    console.log(`[Passenger] 💰 Contraoferta recibida: $${counterMsg.payload.counterPrice}`);

    // --- 5. PASAJERO ACEPTA ---
    console.log('[Passenger] Aceptando trato...');
    
    // El conductor espera el cierre del broadcast
    const closedPromise = waitForEvent(driverSocket, 'offer.closed');

    await axios.post(`${API_URL}/negotiate/accept`, {
      tripId, driverId, clientId: passengerUserId, finalPrice: 90.00
    });

    await closedPromise;
    console.log(`[Driver] 🏁 Negociación cerrada. Viaje asignado.`);

    // --- 6. VERIFICACIÓN FINAL ---
    const trip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (trip && trip.status === 'accepted') {
      console.log('\n✨ [SUCCESS] ¡EL FLUJO DE NEGOCIACIÓN SE HA COMPLETADO EXITOSAMENTE!');
    }

  } catch (error) {
    console.error('\n❌ [ERROR] Fallo en la simulación:', error);
  } finally {
    driverSocket.close();
    passengerSocket.close();
    console.log('\n[Net] Conexiones cerradas.');
    process.exit(0);
  }
}

main();
