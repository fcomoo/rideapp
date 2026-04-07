import { Activity, Car, CheckCircle, DollarSign } from 'lucide-react';
import KPICard from '@/components/dashboard/KPICard';
import AnalyticsChart from '@/components/dashboard/AnalyticsChart';
import StatusTable from '@/components/dashboard/StatusTable';

async function getStats() {
  const res = await fetch('http://localhost:3000/api/stats', { cache: 'no-store' });
  if (!res.ok) return { activeTrips: 0, onlineDrivers: 0, completedToday: 0 };
  return res.json();
}

async function getRecentTrips() {
  const res = await fetch('http://localhost:3000/api/trips', { cache: 'no-store' });
  if (!res.ok) return [];
  return res.json();
}

export default async function DashboardPage() {
  const stats = await getStats();
  const initialTrips = await getRecentTrips();

  return (
    <div className="flex flex-col gap-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold">Admin Dashboard</h2>
          <p className="text-white/50 text-sm mt-1">Real-time overview of your fleet performance</p>
        </div>
        
        <div className="flex gap-3">
          <button className="px-4 py-2 bg-surface border border-border rounded-lg text-sm font-medium hover:bg-white/5 transition-colors">Export CSV</button>
          <button className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-bold hover:opacity-90 transition-opacity">Live Settings</button>
        </div>
      </div>

      {/* KPI Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <KPICard title="Active Trips" value={stats.activeTrips} icon={<Activity size={24} />} trend="12%" isPositive />
        <KPICard title="Online Drivers" value={stats.onlineDrivers} icon={<Car size={24} />} trend="5%" isPositive />
        <KPICard title="Completed Today" value={stats.completedToday} icon={<CheckCircle size={24} />} trend="2%" isPositive />
        <KPICard title="Estimated Revenue" value="$4,250" icon={<DollarSign size={24} />} trend="8%" isPositive />
      </div>

      {/* Main Analytics Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2">
           <AnalyticsChart />
        </div>
        
        <div className="card h-[400px] flex flex-col items-center justify-center text-center gap-4 border-dashed border-2 border-border bg-transparent">
           <div className="p-4 bg-primary/10 rounded-full text-primary">
              <Car size={48} />
           </div>
           <h3 className="font-bold">Dispatch Control</h3>
           <p className="text-white/50 text-sm max-w-[200px]">Live manual dispatch is currently in beta.</p>
        </div>
      </div>

      {/* Recent Trips Table */}
      <div className="flex flex-col gap-4">
        <h3 className="text-xl font-bold">Recent Activity</h3>
        <StatusTable initialTrips={initialTrips} />
      </div>
    </div>
  );
}
