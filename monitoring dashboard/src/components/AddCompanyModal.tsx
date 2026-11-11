import React, { useState } from 'react';
import { X, Building2, Plus, Calendar } from 'lucide-react';
import { CompanyItem, CompanyAccount, MonitorIssueType, ALL_ISSUE_TYPES } from '../types';

interface AddCompanyModalProps {
  onClose: () => void;
  onAddCompany: (company: CompanyItem) => void;
}

export const AddCompanyModal: React.FC<AddCompanyModalProps> = ({
  onClose,
  onAddCompany,
}) => {
  const [name, setName] = useState('');
  const [openIp, setOpenIp] = useState('');
  const [localIp, setLocalIp] = useState('');
  const [siteUser, setSiteUser] = useState('');
  const [sitePassword, setSitePassword] = useState('');

  const [accountUser, setAccountUser] = useState('');
  const [accountPassword, setAccountPassword] = useState('');
  const [consoleUser, setConsoleUser] = useState('');
  const [consolePassword, setConsolePassword] = useState('');

  const [pue, setPue] = useState('1.25');
  const [lastService, setLastService] = useState('2026-10-01');
  const [nextService, setNextService] = useState('2026-12-15');

  const [selectedIssues, setSelectedIssues] = useState<MonitorIssueType[]>([]);
  const [error, setError] = useState('');

  const toggleIssue = (issue: MonitorIssueType) => {
    setSelectedIssues((prev) =>
      prev.includes(issue) ? prev.filter((i) => i !== issue) : [...prev, issue]
    );
  };

  const handleSubmit = (e: React.FormEvent) => {
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

    const accounts: CompanyAccount[] = [];
    if (accountUser.trim() && accountPassword.trim()) {
      accounts.push({
        id: `acc-${Date.now()}-1`,
        username: accountUser.trim(),
        password: accountPassword.trim(),
        isRackConsole: false,
      });
    }
    if (consoleUser.trim() && consolePassword.trim()) {
      accounts.push({
        id: `acc-${Date.now()}-2`,
        username: consoleUser.trim(),
        password: consolePassword.trim(),
        isRackConsole: true,
      });
    }

    const newCompany: CompanyItem = {
      id: `comp-${Date.now()}`,
      name: name.trim(),
      openIp: openIp.trim(),
      localIp: localIp.trim(),
      siteUser: siteUser.trim(),
      sitePassword: sitePassword.trim(),
      isBlocked: false,
      pue: parseFloat(pue) || 1.25,
      lastService,
      nextService,
      activeIssues: selectedIssues,
      accounts,
    };

    onAddCompany(newCompany);
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
              <h3 className="text-base sm:text-lg font-bold text-white">Add Company</h3>
              <p className="text-xs text-white/50">Setup site credentials, accounts, & telemetry</p>
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
              />
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

            {/* Site Credentials */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1.5">
                SITE CREDENTIALS *
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">SITE USER</span>
                  <input
                    type="text"
                    value={siteUser}
                    onChange={(e) => setSiteUser(e.target.value)}
                    placeholder="Site User"
                    className="w-full px-3.5 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                  />
                </div>
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">SITE PASSWORD</span>
                  <input
                    type="text"
                    value={sitePassword}
                    onChange={(e) => setSitePassword(e.target.value)}
                    placeholder="Site Password"
                    className="w-full px-3.5 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                  />
                </div>
              </div>
            </div>

            {/* Initial User Account & Console */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1.5">
                INITIAL ACCOUNTS & RACK CONSOLES (OPTIONAL)
              </label>
              <div className="space-y-3">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3 rounded-xl bg-[#0b1119] border border-[#1e2836]">
                  <div>
                    <span className="text-[10px] font-bold text-white/40 block mb-1">USER ACCOUNT USERNAME</span>
                    <input
                      type="text"
                      value={accountUser}
                      onChange={(e) => setAccountUser(e.target.value)}
                      placeholder="Username"
                      className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                    />
                  </div>
                  <div>
                    <span className="text-[10px] font-bold text-white/40 block mb-1">USER ACCOUNT PASSWORD</span>
                    <input
                      type="text"
                      value={accountPassword}
                      onChange={(e) => setAccountPassword(e.target.value)}
                      placeholder="Password"
                      className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3 rounded-xl bg-[#0b1119] border border-[#1e2836]">
                  <div>
                    <span className="text-[10px] font-bold text-white/40 block mb-1">RACK CONSOLE USERNAME</span>
                    <input
                      type="text"
                      value={consoleUser}
                      onChange={(e) => setConsoleUser(e.target.value)}
                      placeholder="Console Username"
                      className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                    />
                  </div>
                  <div>
                    <span className="text-[10px] font-bold text-white/40 block mb-1">RACK CONSOLE PASSWORD</span>
                    <input
                      type="text"
                      value={consolePassword}
                      onChange={(e) => setConsolePassword(e.target.value)}
                      placeholder="Console Password"
                      className="w-full px-3 py-1.5 bg-[#141d27] border border-[#1e2836] rounded-lg text-xs text-white placeholder-white/30"
                    />
                  </div>
                </div>
              </div>
            </div>

            {/* PUE & Service Dates */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1.5">
                PUE & MAINTENANCE SCHEDULE
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <span className="text-[10px] text-white/40 block mb-1">PUE RATING</span>
                  <input
                    type="number"
                    step="0.01"
                    value={pue}
                    onChange={(e) => setPue(e.target.value)}
                    placeholder="1.25"
                    className="w-full px-3.5 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white"
                  />
                </div>
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
                  <span className="text-[10px] text-white/40 block mb-1">NEXT SERVICE DATE</span>
                  <div className="relative">
                    <input
                      type="date"
                      value={nextService}
                      onChange={(e) => setNextService(e.target.value)}
                      onClick={(e) => e.currentTarget.showPicker && e.currentTarget.showPicker()}
                      style={{ colorScheme: 'dark' }}
                      className="w-full pl-3.5 pr-10 py-2 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white focus:outline-none focus:border-[#00C08B] [color-scheme:dark] [&::-webkit-calendar-picker-indicator]:opacity-0 cursor-pointer"
                    />
                    <Calendar className="w-4 h-4 text-white pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 z-0" />
                  </div>
                </div>
              </div>
            </div>

            {/* Active Issues Selection */}
            <div>
              <label className="text-[11px] font-bold text-[#00C08B] tracking-wider block mb-1">
                ACTIVE SENSOR ISSUES (ONLY CHECK WHAT IS FAILING)
              </label>
              <p className="text-xs text-white/40 mb-2">
                If none are selected, the company will display <span className="text-[#00C08B] font-bold">Issues: None</span>.
              </p>
              <div className="flex flex-wrap gap-2">
                {ALL_ISSUE_TYPES.map((issue) => {
                  const isSelected = selectedIssues.includes(issue);
                  return (
                    <button
                      type="button"
                      key={issue}
                      onClick={() => toggleIssue(issue)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-all cursor-pointer ${
                        isSelected
                          ? 'bg-[#FF3B30]/20 text-[#FF6961] border-[#FF3B30]/50'
                          : 'bg-[#0b1119] text-white/60 border-[#1e2836] hover:text-white'
                      }`}
                    >
                      {isSelected ? `✓ ${issue}` : issue}
                    </button>
                  );
                })}
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
              className="px-6 py-2.5 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] transition-all cursor-pointer flex items-center gap-1.5 shadow-lg shadow-[#00C08B]/20"
            >
              <Plus className="w-4 h-4 stroke-[3]" />
              Create Company
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
