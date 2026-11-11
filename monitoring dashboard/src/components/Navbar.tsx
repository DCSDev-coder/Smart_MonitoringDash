import React, { useState } from 'react';
import {
  Plus,
  Settings,
  LogOut,
  Bell,
  X,
  Flame,
  Calendar,
  Ban,
  CheckCircle2,
} from 'lucide-react';
import { CompanyItem } from '../types';

interface NavbarProps {
  onOpenAddCompany: () => void;
  onOpenSettings: () => void;
  onSignOut: () => void;
  companies: CompanyItem[];
}

export const Navbar: React.FC<NavbarProps> = ({
  onOpenAddCompany,
  onOpenSettings,
  onSignOut,
  companies,
}) => {
  const [showNotifications, setShowNotifications] = useState(false);

  // Generate notifications
  const notifications: Array<{
    id: string;
    title: string;
    subtitle: string;
    time: string;
    type: 'issue' | 'overdue' | 'blocked';
  }> = [];

  companies.forEach((c) => {
    if (c.activeIssues.length > 0) {
      notifications.push({
        id: `notif-issue-${c.id}`,
        title: `${c.name}: ${c.activeIssues.join(', ')} Alert`,
        subtitle: `Telemetry warning detected on ${c.activeIssues.length} sensor(s)`,
        time: 'Active now',
        type: 'issue',
      });
    }

    const isOverdue = new Date(c.nextService) < new Date();
    if (isOverdue) {
      notifications.push({
        id: `notif-service-${c.id}`,
        title: `${c.name}: Service Overdue`,
        subtitle: `Scheduled service was due on ${c.nextService}`,
        time: 'Action required',
        type: 'overdue',
      });
    }

    if (c.isBlocked) {
      notifications.push({
        id: `notif-block-${c.id}`,
        title: `${c.name}: Site Access Suspended`,
        subtitle: `Blocked due to unpaid balance`,
        time: 'Payment pending',
        type: 'blocked',
      });
    }
  });

  const totalNotificationCount = notifications.length;

  return (
    <header className="sticky top-0 z-40 bg-[#0b1119]/95 backdrop-blur-md border-b border-[#1e2836]">
      {/* ─── Header: DCS Logo on Left, Actions & Notification Bell on Right ─── */}
      <div className="w-full px-4 sm:px-6 lg:px-8 py-3.5 relative flex items-center justify-between gap-4">
        {/* LEFT CORNER: DCS LOGO */}
        <div className="flex items-center shrink-0">
          <img
            src="/dcs_logo.png"
            alt="DCS Data Center Specialists"
            className="h-10 sm:h-11 w-auto object-contain drop-shadow transition-transform hover:scale-102"
          />
        </div>

        {/* RIGHT CORNER: Actions + Notification Bell on far corner */}
        <div className="flex items-center gap-2 sm:gap-2.5 shrink-0">
          {/* Action: Add Company */}
          <button
            onClick={onOpenAddCompany}
            className="hidden sm:flex items-center gap-1.5 px-3 py-2 rounded-xl bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] font-bold text-xs transition-all shadow-md shadow-[#00C08B]/15 cursor-pointer active:scale-95"
          >
            <Plus className="w-4 h-4 stroke-[3]" />
            <span>Add Company</span>
          </button>

          {/* Action: Settings */}
          <button
            onClick={onOpenSettings}
            title="Settings & Email Recovery"
            className="p-2 sm:px-3 sm:py-2 rounded-xl bg-[#111922] hover:bg-[#162436] border border-[#1e2836] text-white/80 hover:text-white flex items-center gap-1.5 text-xs font-semibold transition-all cursor-pointer"
          >
            <Settings className="w-4 h-4" />
            <span className="hidden xl:inline">Settings</span>
          </button>

          {/* Action: Sign Out */}
          <button
            onClick={onSignOut}
            title="Sign Out to Login Page"
            className="p-2 sm:px-3 sm:py-2 rounded-xl bg-[#111922] hover:bg-[#FF3B30]/15 border border-[#1e2836] hover:border-[#FF3B30]/40 text-white/70 hover:text-[#FF6961] flex items-center gap-1.5 text-xs font-semibold transition-all cursor-pointer"
          >
            <LogOut className="w-4 h-4" />
            <span className="hidden md:inline">Sign Out</span>
          </button>

          {/* ─── NOTIFICATION BELL ON FAR RIGHT CORNER ─── */}
          <div className="relative">
            <button
              onClick={() => setShowNotifications(!showNotifications)}
              className="p-2.5 rounded-xl bg-[#111922] hover:bg-[#162436] border border-[#1e2836] text-white/90 hover:text-white transition-all cursor-pointer relative shadow-sm"
              title="Notifications"
            >
              <Bell className="w-4 h-4 text-white" />
              {totalNotificationCount > 0 && (
                <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-[#FF3B30] text-white text-[10px] font-extrabold flex items-center justify-center border-2 border-[#0b1119] animate-pulse">
                  {totalNotificationCount}
                </span>
              )}
            </button>

            {/* Notification Drawer Popover */}
            {showNotifications && (
              <>
                <div
                  className="fixed inset-0 z-40"
                  onClick={() => setShowNotifications(false)}
                />
                <div className="absolute right-0 top-full mt-2.5 w-80 sm:w-96 rounded-2xl bg-[#141d27] border border-[#1e2836] shadow-2xl p-4 z-50 animate-fadeIn">
                  <div className="flex items-center justify-between pb-3 border-b border-[#1e2836]">
                    <div className="flex items-center gap-2">
                      <Bell className="w-4 h-4 text-[#00C08B]" />
                      <span className="font-bold text-sm text-white">System Notifications</span>
                    </div>
                    <button
                      onClick={() => setShowNotifications(false)}
                      className="p-1 rounded-lg text-white/40 hover:text-white hover:bg-white/5 transition-colors"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>

                  <div className="mt-3 max-h-72 overflow-y-auto space-y-2 pr-1">
                    {notifications.length === 0 ? (
                      <div className="py-6 text-center text-xs text-white/40">
                        <CheckCircle2 className="w-8 h-8 mx-auto text-[#00C08B]/40 mb-1.5" />
                        All systems normal. No active alerts.
                      </div>
                    ) : (
                      notifications.map((n) => (
                        <div
                          key={n.id}
                          className="p-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-start gap-2.5 text-xs"
                        >
                          <div
                            className={`p-1.5 rounded-lg shrink-0 mt-0.5 ${
                              n.type === 'issue'
                                ? 'bg-[#FF3B30]/15 text-[#FF6961]'
                                : n.type === 'overdue'
                                ? 'bg-[#FF9500]/15 text-[#FF9500]'
                                : 'bg-[#FF3B30]/15 text-[#FF3B30]'
                            }`}
                          >
                            {n.type === 'issue' ? (
                              <Flame className="w-3.5 h-3.5" />
                            ) : n.type === 'overdue' ? (
                              <Calendar className="w-3.5 h-3.5" />
                            ) : (
                              <Ban className="w-3.5 h-3.5" />
                            )}
                          </div>
                          <div className="flex-1 min-w-0">
                            <span className="font-bold text-white block truncate">
                              {n.title}
                            </span>
                            <span className="text-white/60 text-[11px] block truncate">
                              {n.subtitle}
                            </span>
                            <span className="text-[10px] text-white/35 block mt-0.5 font-medium">
                              {n.time}
                            </span>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
