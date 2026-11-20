import React, { useState } from 'react';
import { X, Edit3, Calendar, Save } from 'lucide-react';
import { CompanyItem } from '../types';
import { apiService, calculateNextServiceDate } from '../services/apiService';

interface EditCompanyModalProps {
  company: CompanyItem;
  onClose: () => void;
  onUpdateCompany: (updated: CompanyItem) => void;
}

export const EditCompanyModal: React.FC<EditCompanyModalProps> = ({
  company,
  onClose,
  onUpdateCompany,
}) => {
  const [name, setName] = useState(company.name);
  const [openIp, setOpenIp] = useState(company.openIp);
  const [localIp, setLocalIp] = useState(company.localIp);
  const [siteUser, setSiteUser] = useState(company.siteUser);
  const [sitePassword, setSitePassword] = useState(company.sitePassword);
  const [isBlocked, setIsBlocked] = useState(company.isBlocked);

  const [lastService, setLastService] = useState(company.lastService);
  const expectedNextService = calculateNextServiceDate(lastService);

  const [cctvIp, setCctvIp] = useState(company.cctvIp || '');
  const [cctvUser, setCctvUser] = useState(company.cctvUser || '');
  const [cctvPassword, setCctvPassword] = useState(company.cctvPassword || '');
  const [faceScannerIp, setFaceScannerIp] = useState(company.faceScannerIp || '');
  const [faceScannerUser, setFaceScannerUser] = useState(company.faceScannerUser || '');
  const [faceScannerPassword, setFaceScannerPassword] = useState(company.faceScannerPassword || '');
  const [techNotes, setTechNotes] = useState(company.techNotes || '');
  const [isSaving, setIsSaving] = useState(false);

  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      setError('Company name is required');
      return;
    }
    if (!openIp.trim()) {
      setError('Open IP is required');
      return;
    }
    if (!localIp.trim()) {
      setError('Local IP is required');
      return;
    }
    if (!siteUser.trim() || !sitePassword.trim()) {
      setError('Site User and Site Password are required');
      return;
    }

    setIsSaving(true);
    setError('');

    if (company.id.startsWith('site-')) {
      const siteId = parseInt(company.id.replace('site-', ''), 10);
      if (!isNaN(siteId)) {
        await Promise.all([
          apiService.updateSiteTechDetails(siteId, {
            cctv_ip: cctvIp.trim(),
            cctv_user: cctvUser.trim(),
            cctv_pass: cctvPassword.trim(),
            face_scanner_ip: faceScannerIp.trim(),
            face_scanner_user: faceScannerUser.trim(),
            face_scanner_pass: faceScannerPassword.trim(),
            tech_notes: techNotes.trim(),
          }),
          ...(lastService && lastService !== company.lastService
            ? [apiService.updateSiteMaintenance(siteId, lastService)]
            : []),
        ]);
      }
    }

    const updated: CompanyItem = {
      ...company,
      name: name.trim(),
      openIp: openIp.trim(),
      localIp: localIp.trim(),
      siteUser: siteUser.trim(),
      sitePassword: sitePassword.trim(),
      isBlocked,
      pue: company.pue,
      lastService,
      nextService: expectedNextService || company.nextService,
      activeIssues: company.activeIssues,
      cctvIp: cctvIp.trim(),
      cctvUser: cctvUser.trim(),
      cctvPassword: cctvPassword.trim(),
      faceScannerIp: faceScannerIp.trim(),
      faceScannerUser: faceScannerUser.trim(),
      faceScannerPassword: faceScannerPassword.trim(),
      techNotes: techNotes.trim(),
    };

    onUpdateCompany(updated);
    setIsSaving(false);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
      <div className="w-full max-w-2xl max-h-[90vh] flex flex-col rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl overflow-hidden">
        {/* Pinned Modal Header */}
        <div className="flex items-center justify-between p-6 pb-4 border-b border-[#1e2836] shrink-0 bg-[#111922]">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-[#00C08B]/15 text-[#00C08B] border border-[#00C08B]/30">
              <Edit3 className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white">Edit Company Information</h3>
              <p className="text-xs text-white/50">Update network, credentials, PUE, or maintenance</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-white/40 hover:text-white transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable Form Body */}
        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-5">
          {error && (
            <div className="p-3 rounded-xl bg-[#FF3B30]/15 border border-[#FF3B30]/30 text-xs text-[#FF6961]">
              {error}
            </div>
          )}

          <form id="editCompanyForm" onSubmit={handleSubmit} className="space-y-5">
            {/* 1. Basic Company Details */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-[#00C08B] tracking-wider uppercase">
                  Basic Details & Status
                </span>
                {/* Status Toggle (Active / Blocked) */}
                <button
                  type="button"
                  onClick={() => setIsBlocked(!isBlocked)}
                  className={`px-3 py-1 rounded-full text-xs font-bold border transition-all cursor-pointer flex items-center gap-1.5 ${
                    isBlocked
                      ? 'bg-[#FF3B30]/20 text-[#FF6961] border-[#FF3B30]/40'
                      : 'bg-[#00C08B]/20 text-[#00C08B] border-[#00C08B]/40'
                  }`}
                >
                  <span className={`w-2 h-2 rounded-full ${isBlocked ? 'bg-[#FF3B30]' : 'bg-[#00C08B]'}`} />
                  {isBlocked ? 'Site Blocked' : 'Site Active'}
                </button>
              </div>

              <div>
                <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
                  COMPANY NAME *
                </label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Company Name"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/20 focus:outline-none focus:border-[#00C08B] transition-colors"
                />
              </div>
            </div>

            {/* 2. Network & Site Credentials */}
            <div className="space-y-3 pt-3 border-t border-[#1e2836]/60">
              <span className="text-[11px] font-bold text-[#00C08B] tracking-wider uppercase block">
                Network & Gateway Login
              </span>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
                    OPEN IP (PUBLIC) *
                  </label>
                  <input
                    type="text"
                    value={openIp}
                    onChange={(e) => setOpenIp(e.target.value)}
                    placeholder="Open IP"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/20 focus:outline-none focus:border-[#00C08B] transition-colors"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
                    LOCAL IP (INTERNAL) *
                  </label>
                  <input
                    type="text"
                    value={localIp}
                    onChange={(e) => setLocalIp(e.target.value)}
                    placeholder="Local IP"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/20 focus:outline-none focus:border-[#00C08B] transition-colors"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
                    SITE USERNAME *
                  </label>
                  <input
                    type="text"
                    value={siteUser}
                    onChange={(e) => setSiteUser(e.target.value)}
                    placeholder="Username"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/20 focus:outline-none focus:border-[#00C08B] transition-colors"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
                    SITE PASSWORD *
                  </label>
                  <input
                    type="text"
                    value={sitePassword}
                    onChange={(e) => setSitePassword(e.target.value)}
                    placeholder="Password"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/20 focus:outline-none focus:border-[#00C08B] transition-colors font-mono"
                  />
                </div>
              </div>
            </div>

            {/* Technician Devices & Notes */}
            <div className="space-y-3 pt-3 border-t border-[#1e2836]/60">
              <span className="text-[11px] font-bold text-[#00E5FF] tracking-wider uppercase block">
                Technician Devices &amp; Notes
              </span>

              <div>
                <label className="text-[10px] font-bold text-white/50 tracking-wider block mb-1.5">
                  HIKVISION CCTV
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <input
                    type="text"
                    value={cctvIp}
                    onChange={(e) => setCctvIp(e.target.value)}
                    placeholder="CCTV IP / Host"
                    className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00E5FF] font-mono"
                  />
                  <input
                    type="text"
                    value={cctvUser}
                    onChange={(e) => setCctvUser(e.target.value)}
                    placeholder="CCTV Username"
                    className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00E5FF] font-mono"
                  />
                  <input
                    type="text"
                    value={cctvPassword}
                    onChange={(e) => setCctvPassword(e.target.value)}
                    placeholder="CCTV Password"
                    className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00E5FF] font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="text-[10px] font-bold text-white/50 tracking-wider block mb-1.5">
                  HIKVISION FACE SCANNER
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <input
                    type="text"
                    value={faceScannerIp}
                    onChange={(e) => setFaceScannerIp(e.target.value)}
                    placeholder="Scanner IP / Host"
                    className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00E5FF] font-mono"
                  />
                  <input
                    type="text"
                    value={faceScannerUser}
                    onChange={(e) => setFaceScannerUser(e.target.value)}
                    placeholder="Scanner Username"
                    className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00E5FF] font-mono"
                  />
                  <input
                    type="text"
                    value={faceScannerPassword}
                    onChange={(e) => setFaceScannerPassword(e.target.value)}
                    placeholder="Scanner Password"
                    className="w-full px-3 py-2 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00E5FF] font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="text-[10px] font-bold text-white/50 tracking-wider block mb-1.5">
                  TECHNICIAN NOTES
                </label>
                <textarea
                  rows={3}
                  value={techNotes}
                  onChange={(e) => setTechNotes(e.target.value)}
                  placeholder="Port forwarding, VLAN, router info, or maintenance remarks..."
                  className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00E5FF] resize-y"
                />
              </div>
            </div>

            {/* 3. Maintenance Schedule */}
            <div className="space-y-3 pt-3 border-t border-[#1e2836]/60">
              <span className="text-[11px] font-bold text-[#00C08B] tracking-wider uppercase block">
                Maintenance Schedule
              </span>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
                    LAST SERVICE DATE
                  </label>
                  <div className="relative">
                    <input
                      type="date"
                      value={lastService}
                      onChange={(e) => setLastService(e.target.value)}
                      onClick={(e) => e.currentTarget.showPicker && e.currentTarget.showPicker()}
                      style={{ colorScheme: 'dark' }}
                      className="w-full pl-3.5 pr-10 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs focus:outline-none focus:border-[#00C08B] transition-colors cursor-pointer [&::-webkit-calendar-picker-indicator]:opacity-0"
                    />
                    <Calendar className="w-4 h-4 text-white absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none z-0" />
                  </div>
                </div>
                <div>
                  <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
                    EXPECTED NEXT SERVICE (AUTO +3 MONTHS)
                  </label>
                  <div className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119]/60 border border-[#1e2836] text-[#00C08B] font-mono text-xs flex items-center justify-between">
                    <span>{expectedNextService || '--'}</span>
                    <span className="text-[10px] text-white/40 font-sans">Auto (+90d)</span>
                  </div>
                </div>
              </div>
            </div>
          </form>
        </div>

        {/* Pinned Modal Footer */}
        <div className="flex items-center justify-end gap-3 p-4 sm:p-6 border-t border-[#1e2836] shrink-0 bg-[#111922]">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2.5 rounded-xl text-xs font-semibold text-white/60 hover:text-white bg-[#1e2836] hover:bg-[#2a3a4e] transition-colors cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="submit"
            form="editCompanyForm"
            disabled={isSaving}
            className="px-5 py-2.5 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d69b] text-[#060B11] transition-all shadow-lg shadow-[#00C08B]/20 cursor-pointer flex items-center gap-1.5 disabled:opacity-60"
          >
            <Save className="w-4 h-4" />
            {isSaving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
};
