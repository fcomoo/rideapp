import { PrismaClient } from '@prisma/client';
import WebSocket from 'ws';
import { v4 as uuidv4 } from 'uuid';

const prisma = new PrismaClient();
const WS_URL = 'ws://localhost:3000/ws';

async function main() {
  console.log('🚀 Iniciando Prueba de Flujo Completo Corregida (Antigravity Bridge)\n');

  const passengerUserId = uuidv4();
  const driverUserId = uuidv4();
  const driverId = uuidv4();
  const tripId = uuidv4();

  // --- 1. SETUP BD ---
  await prisma.user.create({ data: { id: passengerUserId, role: 'client', status: 'idle' } });
  await prisma.user.create({ data: { id: driverUserId, role: 'driver', status: 'idle' } });
  await prisma.$executeRawUnsafe(`
    INSERT INTO "Driver" (id, "vehicleDetails", "currentLocation", rating)
    VALUES ('${driverId}', '{"driver_name": "Antigravity Pilot", "license_plate": "AG-2024"}', ST_SetSRID(ST_MakePoint(-99.1332, 19.4326), 4326), 4.9)
  `);
  console.log(`[DB] Entidades creadas.\n`);

  // --- 2. CONECTAR SOCKETS ---
  const passengerSocket = new WebSocket(`${WS_URL}?channel=trip.${tripId}`);
  const driverSocket = new WebSocket(`${WS_URL}?channel=driver.${driverId}`);

  // Helpers para esperar eventos con timeout
  const waitForMessage = (socket: WebSocket, eventType: string, timeoutMs: number = 10000): Promise<any> => {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Timeout esperando evento: ${eventType}`)), timeoutMs);
      const listener = (data: any) => {
        const msg = JSON.parse(data.toString());
        if (msg.event === eventType) {
          clearTimeout(timer);
          socket.removeListener('message', listener);
          resolve(msg);
        }
      };
      socket.on('message', listener);
    });
  };

  const waitForOpen = (socket: WebSocket): Promise<void> => {
    return new Promise((resolve) => socket.on('open', resolve));
  };

  try {
    await Promise.all([waitForOpen(passengerSocket), waitForOpen(driverSocket)]);
    console.log('[Net] Sockets conectados.');

    // --- 3. FLUJO DE SOLICITUD ---
    // El pasajero ESQUCHA ANTES de emitir
    const acceptedPromise = waitForMessage(passengerSocket, 'trip.accepted');

    console.log(`[Passenger] Emitiendo trip.requested...`);
    passengerSocket.send(JSON.stringify({
      event: 'trip.requested',
      channel: `driver.${driverId}`,
      payload: { tripId, clientId: passengerUserId, origin: { latitude: 19.4326, longitude: -99.1332 }, destination: { latitude: 19.4284, longitude: -99.1276 }, offeredPrice: 85.00 }
    }));

    // El conductor recibe y acepta
    console.log(`[Driver] Esperando solicitud...`);
    const requestedEvent = await waitForMessage(driverSocket, 'trip.requested');
    console.log(`[Driver] Solicitud recibida. Aceptando en 2s...`);
    
    await new Promise(r => setTimeout(r, 2000));
    driverSocket.send(JSON.stringify({
      event: 'trip.accepted',
      channel: `trip.${tripId}`,
      payload: { id: tripId, clientId: passengerUserId, driverId: driverId, status: 'accepted', route: [] }
    }));

    // Pasajero recibe aceptación
    const acceptedEvent = await acceptedPromise;
    console.log(`[Passenger] ✨¡Viaje aceptado por ${acceptedEvent.payload.driverId}!`);

    // --- 4. SIMULACIÓN GPS ---
    console.log(`[Driver] Iniciando broadcast de GPS (10s)...`);
    for (let i = 1; i <= 3; i++) {
        await new Promise(r => setTimeout(r, 3000));
        const lat = 19.4326 - (i * 0.001);
        const lng = -99.1332 + (i * 0.001);
        
        driverSocket.send(JSON.stringify({
            event: 'driver.location',
            channel: `trip.${tripId}`,
            payload: { driverId, coords: { latitude: lat, longitude: lng }, timestamp: Date.now() }
        }));
        console.log(`[Driver] GPS Update ${i}/3 enviado.`);
    }

    // --- 5. COMPLETAR ---
    console.log(`[Driver] Finalizando viaje...`);
    const completedPromise = waitForMessage(passengerSocket, 'trip.completed');
    
    driverSocket.send(JSON.stringify({
      event: 'trip.completed',
      channel: `trip.${tripId}`,
      payload: { id: tripId, clientId: passengerUserId, status: 'completed', route: [] }
    }));

    await completedPromise;
    console.log(`🏁 [E2E] ¡EL VIAJE SE HA COMPLETADO EXITOSAMENTE!`);

  } catch (err) {
    console.error('❌ Error en el flujo:', err);
  } finally {
    passengerSocket.close();
    driverSocket.close();
    await prisma.$disconnect();
    console.log('[System] Conexiones cerradas. Saliendo...');
    process.exit(0);
  }
}

main();
