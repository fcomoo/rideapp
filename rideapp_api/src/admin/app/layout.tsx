import type { Metadata } from "next";
import "./globals.css";
import Link from 'next/link';
import { LayoutDashboard, Users, Map as MapIcon, Settings } from 'lucide-react';

export const metadata: Metadata = {
  title: "RideApp Admin | Control Center",
  description: "Real-time fleet monitoring and driver management",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="flex h-screen overflow-hidden">
        {/* Sidebar */}
        <aside className="w-64 bg-surface border-r border-border p-6 flex flex-col gap-8">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-primary rounded-lg flex items-center justify-center font-bold text-white text-xl">R</div>
            <h1 className="font-bold text-lg tracking-tight">RIDEAPP <span className="text-primary">ADMIN</span></h1>
          </div>
          
          <nav className="flex flex-col gap-2">
            <NavLink href="/dashboard" icon={<LayoutDashboard size={20} />} label="Dashboard" />
            <NavLink href="/drivers" icon={<Users size={20} />} label="Drivers" />
            <NavLink href="/map" icon={<MapIcon size={20} />} label="Live Map" />
            <NavLink href="/settings" icon={<Settings size={20} />} label="Settings" />
          </nav>

          <div className="mt-auto p-4 bg-background/50 rounded-xl border border-border">
            <p className="text-xs text-white/50 mb-1 uppercase tracking-widest font-bold">Status</p>
            <div className="flex items-center gap-2">
               <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
               <span className="text-sm font-medium">System Online</span>
            </div>
          </div>
        </aside>

        {/* Main Content */}
        <main className="flex-1 overflow-y-auto p-8 bg-background">
          {children}
        </main>
      </body>
    </html>
  );
}

function NavLink({ href, icon, label }: { href: string; icon: React.ReactNode; label: string }) {
  return (
    <Link 
      href={href} 
      className="flex items-center gap-3 p-3 rounded-lg hover:bg-white/5 transition-colors group"
    >
      <span className="text-white/60 group-hover:text-primary transition-colors">{icon}</span>
      <span className="font-medium text-white/80 group-hover:text-white">{label}</span>
    </Link>
  );
}
