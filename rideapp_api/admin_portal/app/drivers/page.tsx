'use client';

import { useState, useEffect, useMemo } from 'react';
import { Shield, Check, X, Star, RefreshCw, Car, AlertCircle } from 'lucide-react';
import { useAntigravityBridge } from '@/lib/socket';

interface Driver {
  id: string;
  vehicleDetails: {
    driver_name?: string;
    license_plate?: string;
    model?: string;
    email?: string;
  };
  rating: number;
  isVerified: boolean;
  isOnline: boolean;
  tripsCompleted?: number;
  registeredAt?: string;
}

export default function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    fetchDrivers();
  }, []);

  // Escuchar el estado de conexión de conductores en tiempo real
  useAntigravityBridge('admin.drivers', (msg) => {
    if (msg.event === 'driver.status_updated' || msg.event === 'driver.location') {
      const payload = msg.payload;
      setDrivers(prev => prev.map(d => 
        d.id === payload.driverId ? { ...d, isOnline: payload.isOnline ?? d.isOnline } : d
      ));
    }
  });

  const fetchDrivers = async () => {
    setRefreshing(true);
    try {
      const res = await fetch('http://localhost:3000/api/drivers');
      const data = await res.json();
      setDrivers(data);
    } catch (err) {
      console.error('Error fetching drivers:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleVerify = async (id: string, verified: boolean) => {
    // Actualización Optimista: Mover de sección inmediatamente
    setDrivers(prev => prev.map(d => d.id === id ? { ...d, isVerified: verified } : d));

    try {
      const res = await fetch(`http://localhost:3000/api/drivers/${id}/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ verified })
      });
      if (!res.ok) throw new Error('API Error');
    } catch (err) {
      // Rollback en caso de error
      fetchDrivers();
    }
  };

  // Filtrado de secciones
  const pendingDrivers = useMemo(() => drivers.filter(d => !d.isVerified), [drivers]);
  const activeDrivers = useMemo(() => drivers.filter(d => d.isVerified), [drivers]);

  // Estadísticas
  const stats = {
    total: drivers.length,
    pending: pendingDrivers.length,
    onlineNow: activeDrivers.filter(d => d.isOnline).length
  };

  if (loading) return <div className="h-full flex items-center justify-center text-white/40 animate-pulse">Cargando flota de conductores...</div>;

  return (
    <div className="flex flex-col gap-8 pb-12">
      {/* Header & Refresh */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-black tracking-tight">DRIVER NETWORK</h2>
          <p className="text-white/40 text-sm">Gestiona y verifica la flota de Antigravity en tiempo real</p>
        </div>
        <button 
          onClick={fetchDrivers} 
          className="p-3 bg-[#1E1E1E] border border-white/5 rounded-full hover:border-[#FF6B00]/50 transition-colors"
        >
          <RefreshCw size={20} className={refreshing ? 'animate-spin text-[#FF6B00]' : 'text-white/60'} />
        </button>
      </div>

      {/* KPI Section */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <StatItem label="Registrados" value={stats.total} />
        <StatItem label="Pendientes" value={stats.pending} highlight={stats.pending > 0} />
        <StatItem label="Activos Ahora" value={stats.onlineNow} color="#22C55E" />
      </div>

      {drivers.length === 0 ? (
        <EmptyState onRefresh={fetchDrivers} />
      ) : (
        <>
          {/* Pendientes */}
          {pendingDrivers.length > 0 && (
            <div className="flex flex-col gap-4">
              <h3 className="text-sm font-black uppercase tracking-widest text-[#FF6B00] flex items-center gap-2">
                <AlertCircle size={16} /> Pendientes de Verificación
              </h3>
              <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
                {pendingDrivers.map(driver => (
                  <DriverCard 
                    key={driver.id} 
                    driver={driver} 
                    onApprove={() => handleVerify(driver.id, true)} 
                    onReject={() => handleVerify(driver.id, false)}
                  />
                ))}
              </div>
            </div>
          )}

          {/* Activos */}
          <div className="flex flex-col gap-4">
            <h3 className="text-sm font-black uppercase tracking-widest text-white/40 flex items-center gap-2">
              <Shield size={16} /> Conductores Verificados
            </h3>
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
              {activeDrivers.map(driver => (
                <DriverCard key={driver.id} driver={driver} isReadOnly />
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function DriverCard({ driver, onApprove, onReject, isReadOnly = false }: { 
  driver: Driver, onApprove?: () => void, onReject?: () => void, isReadOnly?: boolean 
}) {
  const initials = (driver.vehicleDetails.driver_name || 'U').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);

  return (
    <div className="bg-[#1E1E1E] border border-white/5 rounded-xl p-5 flex gap-5 hover:border-white/10 transition-all group relative">
      <div className="flex-shrink-0 w-16 h-16 bg-[#FF6B00]/10 rounded-full flex items-center justify-center font-black text-xl text-[#FF6B00] border border-[#FF6B00]/20">
        {initials}
      </div>

      <div className="flex-1 flex flex-col gap-1">
        <div className="flex items-center justify-between">
          <h4 className="font-bold text-white text-lg">{driver.vehicleDetails.driver_name || 'Anónimo'}</h4>
          <div className="flex items-center gap-1 text-[#FF6B00] text-sm">
             <Star size={14} fill="#FF6B00" />
             <span className="font-bold">{driver.rating.toFixed(1)}</span>
          </div>
        </div>

        <p className="text-white/40 text-xs mb-2">{driver.vehicleDetails.email || 'no-email@rideapp.com'}</p>
        
        <div className="flex items-center gap-3 text-[11px] font-bold text-white/60">
           <span className="flex items-center gap-1"><Car size={12} /> {driver.vehicleDetails.license_plate}</span>
           <span className="w-1 h-1 bg-white/20 rounded-full" />
           <span>{driver.vehicleDetails.model || 'Standard Vehicle'}</span>
        </div>

        {!isReadOnly && (
          <div className="mt-4 flex gap-2">
            <button onClick={onApprove} className="flex-1 bg-[#22C55E]/10 text-[#22C55E] border border-[#22C55E]/20 py-2 rounded-lg text-xs font-black uppercase hover:bg-[#22C55E] hover:text-white transition-all">Aprobar</button>
            <button onClick={onReject} className="px-4 bg-[#EF4444]/10 text-[#EF4444] border border-[#EF4444]/20 py-2 rounded-lg text-xs font-black uppercase hover:bg-[#EF4444] hover:text-white transition-all">X</button>
          </div>
        )}

        {isReadOnly && (
          <div className="mt-4 flex items-center justify-between">
             <div className="flex items-center gap-1.5">
                <div className={driver.isOnline ? "w-2 h-2 bg-green-500 rounded-full animate-pulse" : "w-2 h-2 bg-white/10 rounded-full"} />
                <span className={`text-[10px] font-black uppercase tracking-tighter ${driver.isOnline ? 'text-green-500' : 'text-white/20'}`}>
                   {driver.isOnline ? 'Online' : 'Offline'}
                </span>
             </div>
             <span className="text-[10px] text-white/30 font-bold uppercase tracking-widest">{driver.tripsCompleted || 0} Viajes</span>
          </div>
        )}
      </div>
    </div>
  );
}

function StatItem({ label, value, color = "#FF6B00", highlight = false }: any) {
  return (
    <div className={`bg-[#1E1E1E] p-5 rounded-2xl border ${highlight ? 'border-[#FF6B00]/40' : 'border-white/5'}`}>
       <p className="text-[10px] font-black uppercase tracking-[0.2em] text-white/30 mb-1">{label}</p>
       <p className="text-3xl font-black" style={{ color }}>{value}</p>
    </div>
  );
}

function EmptyState({ onRefresh }: any) {
  return (
    <div className="card h-64 flex flex-col items-center justify-center gap-4 border-dashed border-2">
       <UserX size={48} className="text-white/20" />
       <p className="text-white/50 text-sm font-bold">No se encontraron conductores en la red.</p>
       <button onClick={onRefresh} className="text-[#FF6B00] text-xs font-black uppercase tracking-widest hover:underline">Reintentar</button>
    </div>
  );
}

// Icono temporal si Lucide no lo tiene en este scope
function UserX(props: any) {
    return <AlertCircle {...props} />
}
