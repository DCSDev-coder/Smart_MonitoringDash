import React, { useState, useMemo } from 'react';
import { X, Server, Globe, Router, User, Lock, Plus } from 'lucide-react';
import { CompanyItem, RackMonitor } from '../types';
import { apiService } from '../services/apiService';

interface AddRackModalProps {
  company: CompanyItem;
  onClose: () => void;
  onAddRack: (companyId: string, rack: RackMonitor) => void;
}

export const AddRackModal: React.FC<AddRackModalProps> = ({
  company,
  onClose,
  onAddRack,
}) => {
  // Auto-suggest next sequential Cabinet ID (e.g. CAB-01 -> CAB-02)
  const suggestedCabinetId = useMemo(() => {
    const existing = company.monitors || [];
    const count = existing.length + 1;
    const numStr = count < 10 ? `0${count}` : `${count}`;
    return `CAB-${numStr}`;
  }, [company.monitors]);

  const [cabinetId, setCabinetId] = useState(suggestedCabinetId);
  const [label, setLabel] = useState(`Rack ${suggestedCabinetId}`);
  const [openIp, setOpenIp] = useState(company.openIp || '');
  const [localIp, setLocalIp] = useState(company.localIp || '');
  const [siteUser, setSiteUser] = useState(company.siteUser || 'admin');
  const [sitePassword, setSitePassword] = useState(company.sitePassword || '');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!cabinetId.trim()) {
      setError('Cabinet ID is required');
      return;
    }
    if (!openIp.trim()) {
      setError('Controller Open IP is required');
      return;
    }
    if (!siteUser.trim() || !sitePassword.trim()) {
      setError('Dahua Site User and Password are required');
      return;
    }

    setIsSubmitting(true);
    setError('');

    // If company is an API site (id starts with "site-"), call the live API
    if (company.id.startsWith('site-')) {
      const siteIdNum = parseInt(company.id.replace('site-', ''), 10);
      if (!isNaN(siteIdNum)) {
        const res = await apiService.addRackMonitor({
          site_id: siteIdNum,
          cabinet_id: cabinetId.trim(),
          label: label.trim() || `Rack ${cabinetId.trim()}`,
          open_ip: openIp.trim(),
          local_ip: localIp.trim(),
          site_user: siteUser.trim(),
          site_pass: sitePassword.trim(),
        });

        if (!res.success) {
          setError(res.message || 'Failed to register rack with portal API');
          setIsSubmitting(false);
          return;
        }
      }
    }

    const newRack: RackMonitor = {
      id: `mon-${Date.now()}`,
      cabinetId: cabinetId.trim(),
      label: label.trim() || `Rack ${cabinetId.trim()}`,
      openIp: openIp.trim(),
      localIp: localIp.trim(),
      siteUser: siteUser.trim(),
      sitePassword: sitePassword.trim(),
      isActive: true,
      pue: 1.25,
      temperature: 24,
      humidity: 45,
      activeIssues: [],
    };

    onAddRack(company.id, newRack);
    setIsSubmitting(false);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
      <div className="w-full max-w-lg rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl p-6 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-[#1e2836]">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-[#00E5FF]/15 text-[#00E5FF]">
              <Server className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white">Add Server Rack Monitor</h3>
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

        {error && (
          <div className="mt-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-xs text-red-400">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="mt-5 space-y-4">
          {/* Cabinet ID & Label */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-white/70 block mb-1">
                Cabinet ID <span className="text-[#00E5FF] text-[10px]">(Auto-suggested)</span>
              </label>
              <input
                type="text"
                value={cabinetId}
                onChange={(e) => setCabinetId(e.target.value)}
                placeholder="e.g. CAB-02"
                className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs focus:outline-none focus:border-[#00E5FF] transition-colors"
                required
              />
            </div>
            <div>
              <label className="text-xs font-semibold text-white/70 block mb-1">
                Rack Label / Location
              </label>
              <input
                type="text"
                value={label}
                onChange={(e) => setLabel(e.target.value)}
                placeholder="e.g. Production DB Rack"
                className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs focus:outline-none focus:border-[#00E5FF] transition-colors"
              />
            </div>
          </div>

          {/* Network IPs */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-white/70 block mb-1">
                Controller Open IP (WAN / WireGuard)
              </label>
              <div className="relative">
                <Globe className="w-4 h-4 text-white/40 absolute left-3 top-2.5" />
                <input
                  type="text"
                  value={openIp}
                  onChange={(e) => setOpenIp(e.target.value)}
                  placeholder="e.g. 219.92.246.237:8002"
                  className="w-full pl-9 pr-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs focus:outline-none focus:border-[#00E5FF] transition-colors"
                  required
                />
              </div>
            </div>
            <div>
              <label className="text-xs font-semibold text-white/70 block mb-1">
                Local IP (LAN)
              </label>
              <div className="relative">
                <Router className="w-4 h-4 text-white/40 absolute left-3 top-2.5" />
                <input
                  type="text"
                  value={localIp}
                  onChange={(e) => setLocalIp(e.target.value)}
                  placeholder="e.g. 172.16.200.3"
                  className="w-full pl-9 pr-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs focus:outline-none focus:border-[#00E5FF] transition-colors"
                />
              </div>
            </div>
          </div>

          {/* Dahua Credentials */}
          <div className="p-3.5 rounded-xl bg-[#0b1119] border border-[#1e2836] space-y-3">
            <span className="text-[10px] font-bold text-white/40 tracking-wider block">
              DAHUA CONTROLLER LOGIN CREDENTIALS
            </span>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-medium text-white/60 block mb-1">
                  Site User
                </label>
                <div className="relative">
                  <User className="w-3.5 h-3.5 text-white/40 absolute left-3 top-2.5" />
                  <input
                    type="text"
                    value={siteUser}
                    onChange={(e) => setSiteUser(e.target.value)}
                    placeholder="admin"
                    className="w-full pl-8 pr-3 py-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white text-xs focus:outline-none focus:border-[#00E5FF] transition-colors"
                    required
                  />
                </div>
              </div>
              <div>
                <label className="text-[11px] font-medium text-white/60 block mb-1">
                  Site Password
                </label>
                <div className="relative">
                  <Lock className="w-3.5 h-3.5 text-white/40 absolute left-3 top-2.5" />
                  <input
                    type="text"
                    value={sitePassword}
                    onChange={(e) => setSitePassword(e.target.value)}
                    placeholder="Controller password"
                    className="w-full pl-8 pr-3 py-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white text-xs focus:outline-none focus:border-[#00E5FF] transition-colors"
                    required
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-2 pt-3 border-t border-[#1e2836]">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-5 py-2 rounded-xl bg-gradient-to-r from-[#00E5FF] to-[#00C08B] text-black text-xs font-bold hover:brightness-110 transition-all cursor-pointer flex items-center gap-1.5"
            >
              <Plus className="w-4 h-4" />
              {isSubmitting ? 'Registering...' : 'Add Server Rack'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
