import React, { useState } from 'react';
import {
  X,
  Globe,
  Router,
  User,
  Key,
  Eye,
  EyeOff,
  Copy,
  Check,
  Shield,
  Edit3,
  Server,
} from 'lucide-react';
import { CompanyItem, RackMonitor } from '../types';

interface SiteCredentialsModalProps {
  company: CompanyItem;
  initialRackId?: string | number;
  onClose: () => void;
  onOpenEdit?: () => void;
}

export const SiteCredentialsModal: React.FC<SiteCredentialsModalProps> = ({
  company,
  initialRackId,
  onClose,
  onOpenEdit,
}) => {
  const monitors: RackMonitor[] = (company.monitors && company.monitors.length > 0)
    ? company.monitors
    : [
        {
          id: 'primary',
          cabinetId: 'CAB-01',
          label: 'Primary Rack',
          openIp: company.openIp,
          localIp: company.localIp,
          siteUser: company.siteUser,
          sitePassword: company.sitePassword,
          isActive: true,
        },
      ];

  const [selectedRackIndex, setSelectedRackIndex] = useState(() => {
    if (initialRackId) {
      const idx = monitors.findIndex((m) => m.id === initialRackId);
      if (idx !== -1) return idx;
    }
    return 0;
  });

  const activeRack = monitors[selectedRackIndex] || monitors[0];

  const [showPassword, setShowPassword] = useState(false);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
      <div className="w-full max-w-lg rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl p-6">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-[#1e2836]">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-[#00C08B]/15 text-[#00C08B]">
              <Shield className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white">Site Network & Credentials</h3>
              <p className="text-xs text-white/50">{company.name}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-white/40 hover:text-white transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Rack Selector Tabs if multiple racks exist */}
        {monitors.length > 1 && (
          <div className="mt-4 flex items-center gap-2 overflow-x-auto pb-1">
            {monitors.map((rack, idx) => (
              <button
                key={rack.id}
                onClick={() => {
                  setSelectedRackIndex(idx);
                  setShowPassword(false);
                }}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer shrink-0 ${
                  selectedRackIndex === idx
                    ? 'bg-[#00E5FF]/20 text-[#00E5FF] border border-[#00E5FF]/50 shadow-sm'
                    : 'bg-[#0b1119] text-white/50 border border-[#1e2836] hover:text-white'
                }`}
              >
                <Server className="w-3.5 h-3.5" />
                <span>{rack.cabinetId || `Rack ${idx + 1}`}</span>
              </button>
            ))}
          </div>
        )}

        {/* Rack Label Banner */}
        <div className="mt-4 p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <span className="px-2 py-0.5 rounded-md bg-[#00E5FF]/15 text-[#00E5FF] border border-[#00E5FF]/30 text-xs font-mono font-bold">
              {activeRack.cabinetId}
            </span>
            <span className="text-xs font-bold text-white">
              {activeRack.label}
            </span>
          </div>
          <span
            className={`text-[10px] px-2 py-0.5 rounded-md font-bold uppercase ${
              activeRack.isActive
                ? 'bg-[#00C08B]/20 text-[#00C08B] border border-[#00C08B]/40'
                : 'bg-[#FF3B30]/20 text-[#FF6961] border border-[#FF3B30]/40'
            }`}
          >
            {activeRack.isActive ? 'Active' : 'Offline'}
          </span>
        </div>

        {/* Credentials List */}
        <div className="mt-4 space-y-3">
          {/* Open IP */}
          <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Globe className="w-4 h-4 text-[#00E5FF] shrink-0" />
              <div>
                <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                  CONTROLLER OPEN IP (WAN)
                </span>
                <span className="text-xs font-semibold text-white font-mono">
                  {activeRack.openIp}
                </span>
              </div>
            </div>
            <button
              onClick={() => copyToClipboard(activeRack.openIp, 'openIp')}
              className="p-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white/50 hover:text-white transition-colors cursor-pointer flex items-center gap-1 text-[11px]"
            >
              {copiedKey === 'openIp' ? (
                <>
                  <Check className="w-3.5 h-3.5 text-[#00C08B]" />
                  <span className="text-[#00C08B]">Copied</span>
                </>
              ) : (
                <>
                  <Copy className="w-3.5 h-3.5" />
                  <span>Copy</span>
                </>
              )}
            </button>
          </div>

          {/* Local IP */}
          {activeRack.localIp && (
            <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
              <div className="flex items-center gap-3">
                <Router className="w-4 h-4 text-[#00E5FF] shrink-0" />
                <div>
                  <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                    LOCAL IP (INTERNAL LAN)
                  </span>
                  <span className="text-xs font-semibold text-white font-mono">
                    {activeRack.localIp}
                  </span>
                </div>
              </div>
              <button
                onClick={() => copyToClipboard(activeRack.localIp || '', 'localIp')}
                className="p-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white/50 hover:text-white transition-colors cursor-pointer flex items-center gap-1 text-[11px]"
              >
                {copiedKey === 'localIp' ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-[#00C08B]" />
                    <span className="text-[#00C08B]">Copied</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5" />
                    <span>Copy</span>
                  </>
                )}
              </button>
            </div>
          )}

          {/* Site User */}
          <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
            <div className="flex items-center gap-3">
              <User className="w-4 h-4 text-[#00C08B] shrink-0" />
              <div>
                <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                  DAHUA SITE USER
                </span>
                <span className="text-xs font-semibold text-white font-mono">
                  {activeRack.siteUser}
                </span>
              </div>
            </div>
            <button
              onClick={() => copyToClipboard(activeRack.siteUser, 'siteUser')}
              className="p-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white/50 hover:text-white transition-colors cursor-pointer flex items-center gap-1 text-[11px]"
            >
              {copiedKey === 'siteUser' ? (
                <>
                  <Check className="w-3.5 h-3.5 text-[#00C08B]" />
                  <span className="text-[#00C08B]">Copied</span>
                </>
              ) : (
                <>
                  <Copy className="w-3.5 h-3.5" />
                  <span>Copy</span>
                </>
              )}
            </button>
          </div>

          {/* Site Password */}
          <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
            <div className="flex items-center gap-3 min-w-0 flex-1 mr-2">
              <Key className="w-4 h-4 text-[#00C08B] shrink-0" />
              <div className="min-w-0 flex-1">
                <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                  DAHUA SITE PASSWORD
                </span>
                <span className="text-xs font-semibold text-white font-mono tracking-wider block truncate">
                  {showPassword ? (activeRack.sitePassword || '••••••••') : '••••••••••••'}
                </span>
              </div>
            </div>
            <div className="flex items-center gap-1.5 shrink-0">
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="p-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white/50 hover:text-white transition-colors cursor-pointer"
                title={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
              </button>
              <button
                onClick={() => copyToClipboard(activeRack.sitePassword || '', 'sitePassword')}
                className="p-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white/50 hover:text-white transition-colors cursor-pointer flex items-center gap-1 text-[11px]"
              >
                {copiedKey === 'sitePassword' ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-[#00C08B]" />
                    <span className="text-[#00C08B]">Copied</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5" />
                    <span>Copy</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="mt-6 flex items-center justify-between pt-4 border-t border-[#1e2836]">
          {onOpenEdit && (
            <button
              onClick={() => {
                onClose();
                onOpenEdit();
              }}
              className="px-3.5 py-2 rounded-xl bg-[#141d27] border border-[#1e2836] text-white/70 hover:text-white text-xs font-bold transition-colors cursor-pointer flex items-center gap-1.5"
            >
              <Edit3 className="w-3.5 h-3.5" />
              Edit Details
            </button>
          )}
          <button
            onClick={onClose}
            className="ml-auto px-5 py-2 rounded-xl bg-[#00C08B] text-black text-xs font-bold hover:brightness-110 transition-all cursor-pointer"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
