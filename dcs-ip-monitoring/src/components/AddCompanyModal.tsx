import React, { useState } from 'react';
import { X, Building2, Plus, Calendar, Server } from 'lucide-react';
import { CompanyItem, CompanyAccount, RackMonitor } from '../types';
import { apiService, calculateNextServiceDate } from '../services/apiService';

interface AddCompanyModalProps {
  onClose: () => void;
  onAddCompany: (company: CompanyItem) => void;
  existingAccounts?: string[];
  initialAccountUser?: string;
}

export const AddCompanyModal: React.FC<AddCompanyModalProps> = ({
  onClose,
  onAddCompany,
  existingAccounts = [],
  initialAccountUser = '',
}) => {
  const [name, setName] = useState('');
  const [cabinetId, setCabinetId] = useState('CAB-01');
  const [rackLabel, setRackLabel] = useState('Main Server Rack');
  const [openIp, setOpenIp] = useState('');
  const [localIp, setLocalIp] = useState('');
  const [siteUser, setSiteUser] = useState('admin');
  const [sitePassword, setSitePassword] = useState('');

  const [selectedExistingAccount, setSelectedExistingAccount] = useState(initialAccountUser);
  const [accountUser, setAccountUser] = useState(initialAccountUser);
  const [accountPassword, setAccountPassword] = useState('');
  const [accountEmail, setAccountEmail] = useState('');

  const [cctvIp, setCctvIp] = useState('');
  const [cctvUser, setCctvUser] = useState('');
  const [cctvPassword, setCctvPassword] = useState('');
  const [faceScannerIp, setFaceScannerIp] = useState('');
  const [faceScannerUser, setFaceScannerUser] = useState('');
  const [faceScannerPassword, setFaceScannerPassword] = useState('');
  const [techNotes, setTechNotes] = useState('');

  const [lastService, setLastService] = useState(() => new Date().toISOString().split('T')[0]);
  const expectedNextService = calculateNextServiceDate(lastService);

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      setError('Company name is required');
      return;
    }
    if (!cabinetId.trim()) {
      setError('Cabinet ID is required');
      return;
    }
    if (!openIp.trim()) {
      setError('Open IP is required');
      return;
    }
    if (!siteUser.trim() || !sitePassword.trim()) {
      setError('Dahua Gateway User and Password are required');
      return;
    }
    if (!accountUser.trim()) {
      setError('Application Admin Username is required (separate from Dahua gateway login)');
      return;
    }
    if (!selectedExistingAccount && !accountPassword.trim()) {
      setError('Application Admin Password is required when creating a new administrator');
      return;
    }

    setIsSubmitting(true);
    setError('');

    // Attempt to register with live portal API
    let assignedSiteId: number | undefined;
    try {
      const apiRes = await apiService.createCompanySite({
        name: name.trim(),
        cabinet_id: cabinetId.trim(),
        label: rackLabel.trim() || `Rack ${cabinetId.trim()}`,
        open_ip: openIp.trim(),
        local_ip: localIp.trim(),
        site_user: siteUser.trim(),
        site_pass: sitePassword.trim(),
        account_user: accountUser.trim() || undefined,
        account_pass: accountPassword.trim() || undefined,
        account_email: accountEmail.trim() || undefined,
        cctv_ip: cctvIp.trim() || undefined,
        cctv_user: cctvUser.trim() || undefined,
        cctv_pass: cctvPassword.trim() || undefined,
        face_scanner_ip: faceScannerIp.trim() || undefined,
        face_scanner_user: faceScannerUser.trim() || undefined,
        face_scanner_pass: faceScannerPassword.trim() || undefined,
        tech_notes: techNotes.trim() || undefined,
      });
      if (apiRes.success && apiRes.site_id) {
        assignedSiteId = apiRes.site_id;
        if (lastService) {
          await apiService.updateSiteMaintenance(apiRes.site_id, lastService);
        }
      }
    } catch {
      // If offline, proceed with local state
    }

    const accounts: CompanyAccount[] = [];
    if (accountUser.trim() && accountPassword.trim()) {
      accounts.push({
        id: `acc-${Date.now()}-1`,
        username: accountUser.trim(),
        email: accountEmail.trim() || undefined,
        password: accountPassword.trim(),
        isRackConsole: false,
      });
    }

    const initialRack: RackMonitor = {
      id: `mon-${Date.now()}`,
      cabinetId: cabinetId.trim(),
      label: rackLabel.trim() || `Rack ${cabinetId.trim()}`,
      openIp: openIp.trim(),
      localIp: localIp.trim(),
      siteUser: siteUser.trim(),
      sitePassword: sitePassword.trim(),
      isActive: true,
      pue: 0,
      temperature: 0,
      humidity: 0,
      activeIssues: [],
    };

    const newCompany: CompanyItem = {
      id: assignedSiteId ? `site-${assignedSiteId}` : `comp-${Date.now()}`,
      name: name.trim(),
      openIp: openIp.trim(),
      localIp: localIp.trim(),
      siteUser: siteUser.trim(),
      sitePassword: sitePassword.trim(),
      isBlocked: false,
      pue: 0,
      lastService,
      nextService: expectedNextService,
      activeIssues: [],
      accounts,
      monitors: [initialRack],
      cctvIp: cctvIp.trim(),
      cctvUser: cctvUser.trim(),
      cctvPassword: cctvPassword.trim(),
      faceScannerIp: faceScannerIp.trim(),
      faceScannerUser: faceScannerUser.trim(),
      faceScannerPassword: faceScannerPassword.trim(),
      techNotes: techNotes.trim(),
    };

    onAddCompany(newCompany);
    setIsSubmitting(false);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
      {/* ─── Outer Modal Card: Rounded & Overflow-Hidden so Scrollbars Never Leak ─── */}
      <div className="w-full max-w-2xl max-h-[88vh] flex flex-col rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl overflow-hidden">
        {/* Fixed Pinned Header */}
        <div className="flex items-center justify-between p-6 pb-4 border-b border-[#1e2836] bg-[#111922] shrink-0">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-[#00C08B]/15 text-[#00C08B]">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base sm:text-lg font-bold text-white">Add Customer Site</h3>
              <p className="text-xs text-white/50">Configure Dahua access and the initial application administrator</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-white/40 hover:text-white transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {error && (
          <div className="mx-6 mt-4 p-3 rounded-xl bg-[#FF3B30]/15 border border-[#FF3B30]/30 text-xs text-[#FF6961] shrink-0">
            {error}
          </div>
        )}

        {/* Form Container with Internal Scrollable Body */}
        <form onSubmit={handleSubmit} className="flex-1 flex flex-col min-h-0 overflow-hidden">
          {/* Scrollable Content Body (Contained cleanly inside with safe padding) */}
          <div className="p-6 overflow-y-auto flex-1 space-y-5 mr-1 pr-5">
            {/* Company Name */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1.5">
                COMPANY NAME *
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Company Name"
                className="w-full px-3.5 py-2.5 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs sm:text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                required
              />
            </div>

            {/* Initial Rack Monitor Details */}
            <div className="p-4 rounded-xl bg-[#0b1119] border border-[#1e2836] space-y-3">
              <div className="flex items-center gap-2">
                <Server className="w-4 h-4 text-[#00E5FF]" />
                <span className="text-[11px] font-bold text-[#00E5FF] tracking-wider">
                  PRIMARY RACK MONITOR (INITIAL SETUP)
                </span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <span className="text-[10px] text-white/50 block mb-1">
                    CABINET ID <span className="text-[#00E5FF]">(Auto-suggested)</span>
                  </span>
                  <input
                    type="text"
                    value={cabinetId}
                    onChange={(e) => setCabinetId(e.target.value)}
                    placeholder="CAB-01"
                    className="w-full px-3.5 py-2 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00E5FF]"
                    required
                  />
                </div>
                <div>
                  <span className="text-[10px] text-white/50 block mb-1">RACK LABEL / NICKNAME</span>
                  <input
                    type="text"
                    value={rackLabel}
                    onChange={(e) => setRackLabel(e.target.value)}
                    placeholder="Main Server Rack"
                    className="w-full px-3.5 py-2 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00E5FF]"
                  />
                </div>
              </div>
            </div>

            {/* Network IPs */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1.5">
                NETWORK CONFIGURATION *
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">OPEN IP</span>
                  <input
                    type="text"
                    value={openIp}
                    onChange={(e) => setOpenIp(e.target.value)}
                    placeholder="Open IP"
                    className="w-full px-3.5 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                  />
                </div>
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">LOCAL IP</span>
                  <input
                    type="text"
                    value={localIp}
                    onChange={(e) => setLocalIp(e.target.value)}
                    placeholder="Local IP"
                    className="w-full px-3.5 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                  />
                </div>
              </div>
            </div>

            {/* Dahua Hardware Gateway Credentials */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1">
                DAHUA GATEWAY CREDENTIALS (HARDWARE ONLY) *
              </label>
              <p className="text-[10px] text-white/40 mb-1.5">
                Used only to connect to the Dahua cabinet controller — cannot be used to sign into the app or website.
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">GATEWAY USER</span>
                  <input
                    type="text"
                    value={siteUser}
                    onChange={(e) => setSiteUser(e.target.value)}
                    placeholder="e.g. admin"
                    className="w-full px-3.5 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                  />
                </div>
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">GATEWAY PASSWORD</span>
                  <input
                    type="password"
                    value={sitePassword}
                    onChange={(e) => setSitePassword(e.target.value)}
                    placeholder="Dahua gateway password"
                    className="w-full px-3.5 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                  />
                </div>
              </div>
            </div>

            {/* Application Administrator */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1.5">
                INTERNAL APPLICATION ADMINISTRATOR *
              </label>
              <p className="text-[10px] text-white/40 mb-1.5">
                This account is for DCS internal operations only. Customer users and rack consoles are created in the main app.
              </p>
              <div className="space-y-3">
                {existingAccounts.length > 0 && (
                  <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836]">
                    <span className="text-[10px] font-bold text-white/50 block mb-1">
                      ASSIGN TO EXISTING INTERNAL ADMIN (MULTI-SITE)
                    </span>
                    <select
                      value={selectedExistingAccount}
                      onChange={(e) => {
                        const val = e.target.value;
                        setSelectedExistingAccount(val);
                        setAccountUser(val);
                        if (val) setAccountPassword('');
                      }}
                      className="w-full px-3 py-2 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white focus:outline-none focus:border-[#00C08B]"
                    >
                        <option value="">+ Create New Internal Admin</option>
                      {existingAccounts.map((acc) => (
                        <option key={acc} value={acc}>
                          {acc} (Existing Internal Admin)
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-3 rounded-xl bg-[#0b1119] border border-[#1e2836]">
                  <div>
                      <span className="text-[10px] font-bold text-white/40 block mb-1">INTERNAL ADMIN USERNAME *</span>
                    <input
                      type="text"
                      value={accountUser}
                      disabled={Boolean(selectedExistingAccount)}
                      onChange={(e) => setAccountUser(e.target.value)}
                      placeholder="New internal admin username"
                      className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30 disabled:opacity-60"
                    />
                  </div>
                  <div>
                    <span className="text-[10px] font-bold text-white/40 block mb-1">
                      {selectedExistingAccount ? 'EXISTING PASSWORD KEPT' : 'INTERNAL ADMIN PASSWORD *'}
                    </span>
                    <input
                      type="password"
                      value={accountPassword}
                      disabled={Boolean(selectedExistingAccount)}
                      onChange={(e) => setAccountPassword(e.target.value)}
                      placeholder={selectedExistingAccount ? 'Uses existing login' : 'Internal admin password'}
                      className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30 disabled:opacity-60"
                    />
                  </div>
                  <div>
                    <span className="text-[10px] font-bold text-white/40 block mb-1">RECOVERY EMAIL</span>
                    <input
                      type="email"
                      value={accountEmail}
                      disabled={Boolean(selectedExistingAccount)}
                      onChange={(e) => setAccountEmail(e.target.value)}
                      placeholder="user@company.com"
                      className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30 disabled:opacity-60"
                    />
                  </div>
                </div>

              </div>
            </div>

            {/* Technician Devices & Notes */}
            <div className="p-3.5 rounded-xl bg-[#0b1119] border border-[#1e2836] space-y-3">
              <label className="text-[11px] font-bold text-[#00E5FF] tracking-wider block">
                TECHNICIAN DEVICES &amp; NOTES (OPTIONAL)
              </label>

              {/* Hikvision CCTV */}
              <div>
                <span className="text-[10px] font-bold text-white/50 block mb-1.5">
                  HIKVISION CCTV
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <input
                    type="text"
                    value={cctvIp}
                    onChange={(e) => setCctvIp(e.target.value)}
                    placeholder="CCTV IP / Host"
                    className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                  />
                  <input
                    type="text"
                    value={cctvUser}
                    onChange={(e) => setCctvUser(e.target.value)}
                    placeholder="CCTV Username"
                    className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                  />
                  <input
                    type="text"
                    value={cctvPassword}
                    onChange={(e) => setCctvPassword(e.target.value)}
                    placeholder="CCTV Password"
                    className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                  />
                </div>
              </div>

              {/* Hikvision Face Scanner */}
              <div>
                <span className="text-[10px] font-bold text-white/50 block mb-1.5">
                  HIKVISION FACE SCANNER
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <input
                    type="text"
                    value={faceScannerIp}
                    onChange={(e) => setFaceScannerIp(e.target.value)}
                    placeholder="Scanner IP / Host"
                    className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                  />
                  <input
                    type="text"
                    value={faceScannerUser}
                    onChange={(e) => setFaceScannerUser(e.target.value)}
                    placeholder="Scanner Username"
                    className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                  />
                  <input
                    type="text"
                    value={faceScannerPassword}
                    onChange={(e) => setFaceScannerPassword(e.target.value)}
                    placeholder="Scanner Password"
                    className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                  />
                </div>
              </div>

              {/* Technician Notes */}
              <div>
                <span className="text-[10px] font-bold text-white/50 block mb-1.5">
                  TECHNICIAN NOTES
                </span>
                <textarea
                  rows={2}
                  value={techNotes}
                  onChange={(e) => setTechNotes(e.target.value)}
                  placeholder="Port forwarding, VLAN, router info, or maintenance remarks..."
                  className="w-full px-3 py-2 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30 resize-y"
                />
              </div>
            </div>

            {/* Maintenance Schedule */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1.5">
                MAINTENANCE SCHEDULE
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">LAST SERVICE DATE</span>
                  <div className="relative">
                    <input
                      type="date"
                      value={lastService}
                      onChange={(e) => setLastService(e.target.value)}
                      onClick={(e) => e.currentTarget.showPicker && e.currentTarget.showPicker()}
                      style={{ colorScheme: 'dark' }}
                      className="w-full pl-3.5 pr-10 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white focus:outline-none focus:border-[#00C08B] [color-scheme:dark] [&::-webkit-calendar-picker-indicator]:opacity-0 cursor-pointer"
                    />
                    <Calendar className="w-4 h-4 text-white pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 z-0" />
                  </div>
                </div>
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">NEXT SERVICE DATE (AUTO +3 MONTHS)</span>
                  <div className="w-full px-3.5 py-2 bg-[#0b1119]/60 border border-[#1e2836] rounded-xl text-xs text-[#00C08B] font-mono flex items-center justify-between">
                    <span>{expectedNextService || '--'}</span>
                    <span className="text-[10px] text-white/40 font-sans">Auto (+90d)</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Fixed Pinned Footer with Action Buttons */}
          <div className="p-4 sm:px-6 border-t border-[#1e2836] bg-[#0c131c] shrink-0 flex items-center justify-end gap-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2.5 rounded-xl text-xs font-semibold text-white/60 hover:text-white transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-6 py-2.5 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] transition-all cursor-pointer flex items-center gap-1.5 shadow-lg shadow-[#00C08B]/20 disabled:opacity-50"
            >
              <Plus className="w-4 h-4 stroke-[3]" />
              {isSubmitting ? 'Creating Site...' : 'Create Customer Site'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
