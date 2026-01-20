import React from 'react';
import { motion } from 'framer-motion';
import { LayoutDashboard, History, Fish, Settings } from 'lucide-react';
export type TabId = 'dashboard' | 'history' | 'info' | 'settings';
interface TabNavigationProps {
  activeTab: TabId;
  onTabChange: (tab: TabId) => void;
}
export function TabNavigation({
  activeTab,
  onTabChange
}: TabNavigationProps) {
  const tabs = [{
    id: 'dashboard',
    icon: LayoutDashboard
  }, {
    id: 'history',
    icon: History
  }, {
    id: 'info',
    icon: Fish
  }, {
    id: 'settings',
    icon: Settings
  }] as const;
  return <div className="absolute bottom-6 left-0 right-0 flex justify-center items-end z-50 pointer-events-none">
      <div className="flex items-end gap-3 px-4 pointer-events-auto">
        {tabs.map(tab => {
        const isActive = activeTab === tab.id;
        return <motion.button key={tab.id} onClick={() => onTabChange(tab.id)} layout className={`relative flex items-center justify-center rounded-full shadow-lg backdrop-blur-md border border-white/20 transition-colors duration-300 ${isActive ? 'bg-gradient-to-br from-teal-500 to-cyan-600 text-white shadow-teal-500/30' : 'bg-white/90 text-slate-400 hover:text-teal-600'}`} animate={{
          width: isActive ? 64 : 48,
          height: isActive ? 64 : 48,
          y: isActive ? -10 : 0
        }} whileTap={{
          scale: 0.9
        }} transition={{
          type: 'spring',
          stiffness: 400,
          damping: 25
        }}>
              {isActive && <motion.div className="absolute inset-0 rounded-full bg-white/20" initial={{
            scale: 0
          }} animate={{
            scale: 1.5,
            opacity: 0
          }} transition={{
            duration: 1,
            repeat: Infinity
          }} />}
              <tab.icon size={isActive ? 28 : 22} strokeWidth={isActive ? 2.5 : 2} />
            </motion.button>;
      })}
      </div>
    </div>;
}