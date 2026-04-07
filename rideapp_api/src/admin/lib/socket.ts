'use client';

import { useEffect, useRef } from 'react';

type Message = {
  event: string;
  channel: string;
  payload: any;
};

export function useAntigravityBridge(channel: string, onMessage: (msg: Message) => void) {
  const ws = useRef<WebSocket | null>(null);

  useEffect(() => {
    const connect = () => {
      console.log(`[Admin] Connecting to Antigravity Bridge: ${channel}`);
      ws.current = new WebSocket(`ws://localhost:3000/ws?channel=${channel}`);

      ws.current.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          onMessage(data);
        } catch (err) {
          console.error('[Admin] WS Parse Error:', err);
        }
      };

      ws.current.onclose = () => {
        console.log('[Admin] WS Disconnected. Retrying in 5s...');
        setTimeout(connect, 5000);
      };

      ws.current.onerror = (err) => {
        console.error('[Admin] WS Error:', err);
        ws.current?.close();
      };
    };

    connect();

    return () => {
      ws.current?.close();
    };
  }, [channel, onMessage]);

  const send = (event: string, payload: any) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify({ event, channel, payload }));
    }
  };

  return { send };
}
