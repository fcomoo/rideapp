'use client';

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

const data = [
  { time: '08:00', trips: 12 },
  { time: '10:00', trips: 45 },
  { time: '12:00', trips: 78 },
  { time: '14:00', trips: 56 },
  { time: '16:00', trips: 145 },
  { time: '18:00', trips: 210 },
  { time: '20:00', trips: 134 },
];

export default function AnalyticsChart() {
  return (
    <div className="bg-[#1E1E1E] border border-white/5 p-6 rounded-xl shadow-xl h-[400px]">
      <h3 className="text-white font-black uppercase tracking-tighter mb-4 flex items-center justify-between">
        Trip Volume <span className="text-[10px] text-white/30 tracking-widest font-bold font-mono">LIVE / 12H</span>
      </h3>
      <ResponsiveContainer width="100%" height="90%">
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#2A2A2A" vertical={false} />
          <XAxis 
            dataKey="time" 
            stroke="#666" 
            fontSize={12} 
            tickLine={false} 
            axisLine={false} 
            dy={10}
          />
          <YAxis 
            stroke="#666" 
            fontSize={12} 
            tickLine={false} 
            axisLine={false} 
          />
          <Tooltip 
            contentStyle={{ backgroundColor: '#121212', border: '1px solid #FF6B00', borderRadius: '8px' }}
            itemStyle={{ color: '#FF6B00' }}
          />
          <Line 
            type="monotone" 
            dataKey="trips" 
            stroke="#FF6B00" 
            strokeWidth={4} 
            dot={{ r: 4, fill: '#FF6B00' }} 
            activeDot={{ r: 8, stroke: '#FF6B00', strokeWidth: 2, fill: '#121212' }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
