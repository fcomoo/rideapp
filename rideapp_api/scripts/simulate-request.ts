import WebSocket from 'ws';

const WS_URL = 'ws://localhost:3000/ws';
const driverId = 'test-driver-456';
const tripId = 'sim-trip-' + Date.now();

async function main() {
  console.log('🚀 Simulando Solicitud de Viaje para Conductor ' + driverId);
  
  const client = new WebSocket(`${WS_URL}?channel=driver.${driverId}`);

  client.on('open', () => {
    console.log('[Net] Conectado al canal del conductor.');

    const payload = {
      event: `driver.${driverId}.request`,
      channel: `driver.${driverId}`,
      payload: {
        trip: {
          id: tripId,
          clientId: 'maria-gonzalez-123',
          driverId: driverId,
          origin: { latitude: 17.7600, longitude: -92.5950 },
          destination: { latitude: 17.7650, longitude: -92.6000 },
          price: 95.00,
          status: 'requested',
          distance: 1.4
        }
      }
    };

    console.log('[Sim] Emitiendo evento .request...');
    client.send(JSON.stringify(payload));

    setTimeout(() => {
      console.log('[Sim] Simulación completada. Cerrando socket.');
      client.close();
      process.exit(0);
    }, 2000);
  });

  client.on('error', (err) => {
    console.error('❌ Error en WebSocket:', err);
    process.exit(1);
  });
}

main();
