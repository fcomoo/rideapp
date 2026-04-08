'use client';

import { useState } from 'react';
import { useAntigravityBridge } from '@/lib/socket';

interface Trip {
  id: string;
  clientId: string;
  driverId: string | null;
  status: 'requested' | 'accepted' | 'in_progress' | 'completed' | 'cancelled';
  price?: number;
}

interface StatusTableProps {
  initialTrips: Trip[];
}

export default function StatusTable({ initialTrips }: StatusTableProps) {
  const [trips, setTrips] = useState<Trip[]>(initialTrips);

  // Escuchar actualizaciones en tiempo real del canal de administración
  useAntigravityBridge('admin.dashboard', (msg) => {
    if (msg.event.startsWith('trip.')) {
      setTrips(prev => {
        const payload = msg.payload as Trip;
        const exists = prev.find(t => t.id === payload.id);
        if (exists) {
            return prev.map(t => t.id === payload.id ? { ...t, ...payload } : t);
        } else {
            return [payload, ...prev].slice(0, 10);
        }
      });
    }
  });

  const getStatusStyle = (status: string) => {
    switch (status) {
      case 'requested': return 'bg-blue-500/10 text-[#3B82F6] border-[#3B82F6]';
      case 'accepted': return 'bg-yellow-500/10 text-[#FACC15] border-[#FACC15]';
      case 'in_progress': return 'bg-orange-500/10 text-[#FB923C] border-[#FB923C]';
      case 'completed': return 'bg-green-500/10 text-[#22C55E] border-[#22C55E]';
      case 'cancelled': return 'bg-red-500/10 text-[#EF4444] border-[#EF4444]';
      default: return 'bg-white/5 text-white/50 border-white/20';
    }
  };

  return (
    <div className="bg-[#1E1E1E] rounded-xl border border-white/5 overflow-hidden shadow-2xl">
      <table className="w-full text-left text-sm border-collapse">
        <thead className="bg-white/5 border-b border-white/5 text-[10px] font-black uppercase tracking-widest text-white/30">
          <tr>
            <th className="px-6 py-4">Trip ID</th>
            <th className="px-6 py-4">Pasajero</th>
            <th className="px-6 py-4">Conductor</th>
            <th className="px-6 py-4">Status</th>
            <th className="px-6 py-4 text-right">Precio</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-white/5">
          {trips.length === 0 ? (
            <tr>
              <td colSpan={5} className="px-6 py-12 text-center text-white/20 italic">No activity detected. Listening...</td>
            </tr>
          ) : (
            trips.map((trip) => (
              <tr key={trip.id} className="hover:bg-white/[0.02] transition-colors group">
                <td className="px-6 py-4 font-mono text-primary font-bold">{trip.id.slice(0, 8)}</td>
                <td className="px-6 py-4 text-white/80 font-medium">{trip.clientId.slice(0, 6)}</td>
                <td className="px-6 py-4 text-white/80 font-medium italic">
                    {trip.driverId ? trip.driverId.slice(0, 6) : '---'}
                </td>
                <td className="px-6 py-4">
                  <span className={`px-2 py-1 rounded-md text-[10px] font-black uppercase tracking-tighter border ${getStatusStyle(trip.status)}`}>
                    {trip.status.replace('_', ' ')}
                  </span>
                </td>
                <td className="px-6 py-4 text-right font-bold text-white/90">
                    ${(trip.price || 24.50).toFixed(2)}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
      <div className="p-4 bg-white/5 text-[9px] text-white/20 uppercase font-black tracking-widest flex items-center justify-between">
        <span>Showing last 10 trips</span>
        <span className="flex items-center gap-1">
            <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
            Live Sync: Active
        </span>
      </div>
    </div>
  );
}
