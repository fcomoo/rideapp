import { ReactNode } from 'react';

interface KPICardProps {
  title: string;
  value: string | number;
  icon: ReactNode;
  color?: string;
}

export default function KPICard({ title, value, icon, color = "#FF6B00" }: KPICardProps) {
  return (
    <div className="bg-[#1E1E1E] border-l-4 border-[#FF6B00] rounded-xl p-6 shadow-lg flex flex-col gap-2 transition-transform hover:scale-[1.02]">
      <div className="flex items-center justify-between text-white/60 mb-2">
        <span className="text-xs font-bold uppercase tracking-widest">{title}</span>
        <div style={{ color }}>{icon}</div>
      </div>
      <div className="text-4xl font-black text-white tracking-tight">
        {value}
      </div>
      <div className="text-[10px] text-white/30 font-medium italic">
        Real-time telemetry active
      </div>
    </div>
  );
}
