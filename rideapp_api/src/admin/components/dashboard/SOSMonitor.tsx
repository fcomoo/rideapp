'use client';

import React, { useState, useEffect } from 'react';
import { AlertCircle, MapPin, CheckCircle, ExternalLink } from 'lucide-react';

interface SOSAlert {
  userId: string;
  tripId?: string;
  lat: number;
  lng: number;
  timestamp: number;
  message: string;
}

export default function SOSMonitor() {
  const [alerts, setAlerts] = useState<SOSAlert[]>([]);

  useEffect(() => {
    // Escuchar el canal global de emergencias via WebSockets
    const ws = new WebSocket('ws://localhost:3000/ws?channel=admin.emergency');
    
    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.event === 'sos.alert') {
          const newAlert = data.payload as SOSAlert;
          
          // Verificar si ya existe (evitar duplicados por reconexión)
          setAlerts(prev => {
            if (prev.some(a => a.timestamp === newAlert.timestamp)) return prev;
            
            // Beep Sound (Web Audio API para evitar depender de archivos externos)
            const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
            const oscillator = audioCtx.createOscillator();
            const gainNode = audioCtx.createGain();

            oscillator.type = 'sawtooth';
            oscillator.frequency.setValueAtTime(440, audioCtx.currentTime);
            oscillator.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 0.3);
            
            gainNode.gain.setValueAtTime(0.2, audioCtx.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.5);

            oscillator.connect(gainNode);
            gainNode.connect(audioCtx.destination);

            oscillator.start();
            oscillator.stop(audioCtx.currentTime + 0.5);

            return [newAlert, ...prev];
          });
        }
      } catch (err) {
        console.error('Error parsing SOS alert:', err);
      }
    };

    return () => ws.close();
  }, []);

  const handleDismiss = (timestamp: number) => {
    setAlerts(prev => prev.filter(a => a.timestamp !== timestamp));
  };

  if (alerts.length === 0) return null;

  return (
    <div className="fixed top-24 right-8 z-[60] flex flex-col gap-4 w-[380px] pointer-events-none">
      {alerts.map((alert) => (
        <div 
          key={alert.timestamp} 
          className="pointer-events-auto animate-bounce bg-red-600 border-2 border-red-400 rounded-2xl p-5 shadow-[0_0_50px_rgba(220,38,38,0.5)] text-white"
        >
          <div className="flex items-start gap-4">
            <div className="bg-white p-2 rounded-full animate-pulse shadow-lg">
              <AlertCircle className="w-8 h-8 text-red-600" />
            </div>
            <div className="flex-1">
              <div className="flex items-center justify-between">
                <h4 className="font-black text-xl tracking-tighter">ALERTA SOS</h4>
                <span className="text-[10px] bg-black/30 px-2 py-0.5 rounded-full font-mono uppercase">
                  {new Date(alert.timestamp).toLocaleTimeString()}
                </span>
              </div>
              <p className="text-white/90 text-sm font-medium mt-1">ID: {alert.userId}</p>
              {alert.tripId && <p className="text-white/70 text-[10px]">Trip: {alert.tripId}</p>}
            </div>
          </div>

          <div className="mt-5 space-y-3">
            <div className="bg-black/20 backdrop-blur-sm p-4 rounded-xl flex items-center justify-between border border-white/10">
                <div className="flex items-center gap-3">
                    <MapPin className="w-5 h-5 text-red-200" />
                    <span className="text-sm font-bold font-mono tracking-wide">
                        {alert.lat.toFixed(6)}, {alert.lng.toFixed(6)}
                    </span>
                </div>
                <a 
                  href={`https://www.google.com/maps?q=${alert.lat},${alert.lng}`} 
                  target="_blank" 
                  rel="noreferrer"
                  className="p-2 bg-white text-red-600 rounded-lg hover:scale-110 active:scale-95 transition-transform"
                  title="Ver en Maps"
                >
                  <ExternalLink className="w-4 h-4" />
                </a>
            </div>
            
            <button 
              onClick={() => handleDismiss(alert.timestamp)}
              className="group w-full h-12 bg-green-500 hover:bg-green-400 text-white font-black rounded-xl flex items-center justify-center gap-3 transition-all shadow-xl active:scale-[0.98]"
            >
              <CheckCircle className="w-6 h-6 group-hover:scale-125 transition-transform" />
              ATENDER EMERGENCIA
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
