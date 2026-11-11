import { useState, useEffect } from 'react';
import { Navbar } from './components/Navbar';
import { CompanyCard } from './components/CompanyCard';
import { AddCompanyModal } from './components/AddCompanyModal';
import { AddAccountModal } from './components/AddAccountModal';
import { SettingsModal } from './components/SettingsModal';
import { LoginModal } from './components/LoginModal';
import {
  loadCompanies,
  saveCompanies,
  loadRecoveryEmail,
  saveRecoveryEmail,
} from './mockData';
import { CompanyItem, CompanyAccount, CompanyFilter } from './types';
import {
  Building2,
  CheckCircle2,
  Ban,
  AlertTriangle,
  Search,
  X,
  Inbox,
  Filter,
  LogOut,
} from 'lucide-react';

export function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(() => {
    return localStorage.getItem('dcstack_auth_session') === 'true';
  });
  const [companies, setCompanies] = useState<CompanyItem[]>([]);
  const [recoveryEmail, setRecoveryEmail] = useState<string>('admin@dcstack.my');

  const handleLogin = () => {
    localStorage.setItem('dcstack_auth_session', 'true');
    setIsLoggedIn(true);
  };

  const handleSignOut = () => {
    localStorage.removeItem('dcstack_auth_session');
    setIsLoggedIn(false);
  };

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('');
  const [filter, setFilter] = useState<CompanyFilter>('all');

  // Modals
  const [showAddCompany, setShowAddCompany] = useState(false);
  const [accountModalCompanyId, setAccountModalCompanyId] = useState<string | null>(null);
  const [showSettings, setShowSettings] = useState(false);
  const [showSignOutConfirm, setShowSignOutConfirm] = useState(false);

  // Initialize data from LocalStorage
  useEffect(() => {
    setCompanies(loadCompanies());
    setRecoveryEmail(loadRecoveryEmail());
  }, []);

  // Handlers for companies
  const handleToggleBlock = (companyId: string) => {
    const updated = companies.map((c) =>
      c.id === companyId ? { ...c, isBlocked: !c.isBlocked } : c
    );
    setCompanies(updated);
    saveCompanies(updated);
  };

  const handleAddCompany = (newCompany: CompanyItem) => {
    const updated = [newCompany, ...companies];
    setCompanies(updated);
    saveCompanies(updated);
  };

  const handleDeleteCompany = (companyId: string) => {
    const updated = companies.filter((c) => c.id !== companyId);
    setCompanies(updated);
    saveCompanies(updated);
  };

  const handleAddAccount = (companyId: string, account: CompanyAccount) => {
    const updated = companies.map((c) => {
      if (c.id === companyId) {
        return {
          ...c,
          accounts: [...c.accounts, account],
        };
      }
      return c;
    });
    setCompanies(updated);
    saveCompanies(updated);
  };

  const handleDeleteAccount = (companyId: string, accountId: string) => {
    const updated = companies.map((c) => {
      if (c.id === companyId) {
        return {
          ...c,
          accounts: c.accounts.filter((a) => a.id !== accountId),
        };
      }
      return c;
    });
    setCompanies(updated);
    saveCompanies(updated);
  };

  const handleSaveEmail = (newEmail: string) => {
    setRecoveryEmail(newEmail);
    saveRecoveryEmail(newEmail);
  };

  // Status Metrics
  const totalCompanies = companies.length;
  const blockedCompanies = companies.filter((c) => c.isBlocked).length;
  const activeCompanies = totalCompanies - blockedCompanies;
  const companiesWithIssues = companies.filter((c) => c.activeIssues.length > 0).length;

  // Filtered companies
  const filteredCompanies = companies.filter((c) => {
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const matchName = c.name.toLowerCase().includes(q);
      const matchOpenIp = c.openIp.toLowerCase().includes(q);
      const matchLocalIp = c.localIp.toLowerCase().includes(q);
      const matchUser = c.siteUser.toLowerCase().includes(q);
      if (!matchName && !matchOpenIp && !matchLocalIp && !matchUser) {
        return false;
      }
    }

    if (filter === 'active') return !c.isBlocked;
    if (filter === 'blocked') return c.isBlocked;
    if (filter === 'issues') return c.activeIssues.length > 0;
    return true;
  });

  const targetAccountCompany = companies.find((c) => c.id === accountModalCompanyId);

  // If not logged in, show the login view
  if (!isLoggedIn) {
    return (
      <LoginModal
        onLogin={handleLogin}
        recoveryEmail={recoveryEmail}
      />
    );
  }

  return (
    <div className="min-h-screen bg-[#060B11] text-white flex flex-col font-sans">
      {/* ─── Top Navigation: Logo Left, Title Centered, Actions/Bell Right ─── */}
      <Navbar
        onOpenAddCompany={() => setShowAddCompany(true)}
        onOpenSettings={() => setShowSettings(true)}
        onSignOut={() => setShowSignOutConfirm(true)}
        companies={companies}
      />

      {/* ─── Main Content Area (Full Screen Width with Generous Spacing) ─── */}
      <main className="flex-1 w-full px-4 sm:px-8 lg:px-12 py-8 space-y-8 sm:space-y-10">
        {/* ─── 1. STATUS CARDS (Generous Gaps & Padding) ─── */}
        <section aria-label="Company Status Overview">
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            {/* Card 1: Total Companies */}
            <button
              onClick={() => setFilter('all')}
              className={`p-4 sm:p-5 rounded-2xl border transition-all text-left flex flex-col justify-between cursor-pointer group shadow-sm min-h-[108px] ${
                filter === 'all'
                  ? 'bg-[#141d27] border-[#00E5FF] shadow-[#00E5FF]/10 ring-1 ring-[#00E5FF]/30'
                  : 'bg-[#111922] border-[#1e2836] hover:border-[#2a3a4e] hover:bg-[#141d27]'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="w-8 h-8 rounded-xl bg-[#00E5FF]/15 text-[#00E5FF] flex items-center justify-center border border-[#00E5FF]/30">
                  <Building2 className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-black tracking-widest uppercase text-white/40">
                  TOTAL
                </span>
              </div>
              <div className="mt-3 flex items-baseline justify-between gap-2">
                <span className="text-xs font-bold text-white/60 tracking-wider uppercase">
                  All Companies
                </span>
                <span className="text-2xl sm:text-3xl font-black text-white tracking-tight">
                  {totalCompanies}
                </span>
              </div>
            </button>

            {/* Card 2: Active Sites */}
            <button
              onClick={() => setFilter('active')}
              className={`p-4 sm:p-5 rounded-2xl border transition-all text-left flex flex-col justify-between cursor-pointer group shadow-sm min-h-[108px] ${
                filter === 'active'
                  ? 'bg-[#141d27] border-[#00C08B] shadow-[#00C08B]/10 ring-1 ring-[#00C08B]/30'
                  : 'bg-[#111922] border-[#1e2836] hover:border-[#2a3a4e] hover:bg-[#141d27]'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="w-8 h-8 rounded-xl bg-[#00C08B]/15 text-[#00C08B] flex items-center justify-center border border-[#00C08B]/30">
                  <CheckCircle2 className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-black tracking-widest uppercase text-[#00C08B]">
                  ONLINE
                </span>
              </div>
              <div className="mt-3 flex items-baseline justify-between gap-2">
                <span className="text-xs font-bold text-white/60 tracking-wider uppercase">
                  Active Sites
                </span>
                <span className="text-2xl sm:text-3xl font-black text-[#00C08B] tracking-tight">
                  {activeCompanies}
                </span>
              </div>
            </button>

            {/* Card 3: Blocked Sites */}
            <button
              onClick={() => setFilter('blocked')}
              className={`p-4 sm:p-5 rounded-2xl border transition-all text-left flex flex-col justify-between cursor-pointer group shadow-sm min-h-[108px] ${
                filter === 'blocked'
                  ? 'bg-[#141d27] border-[#FF3B30] shadow-[#FF3B30]/10 ring-1 ring-[#FF3B30]/30'
                  : 'bg-[#111922] border-[#1e2836] hover:border-[#2a3a4e] hover:bg-[#141d27]'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="w-8 h-8 rounded-xl bg-[#FF3B30]/15 text-[#FF3B30] flex items-center justify-center border border-[#FF3B30]/30">
                  <Ban className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-black tracking-widest uppercase text-[#FF6961]">
                  HOLD
                </span>
              </div>
              <div className="mt-3 flex items-baseline justify-between gap-2">
                <span className="text-xs font-bold text-white/60 tracking-wider uppercase">
                  Blocked (Unpaid)
                </span>
                <span className="text-2xl sm:text-3xl font-black text-[#FF6961] tracking-tight">
                  {blockedCompanies}
                </span>
              </div>
            </button>

            {/* Card 4: Issues Detected */}
            <button
              onClick={() => setFilter('issues')}
              className={`p-4 sm:p-5 rounded-2xl border transition-all text-left flex flex-col justify-between cursor-pointer group shadow-sm min-h-[108px] ${
                filter === 'issues'
                  ? 'bg-[#141d27] border-[#FF9500] shadow-[#FF9500]/10 ring-1 ring-[#FF9500]/30'
                  : 'bg-[#111922] border-[#1e2836] hover:border-[#2a3a4e] hover:bg-[#141d27]'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="w-8 h-8 rounded-xl bg-[#FF9500]/15 text-[#FF9500] flex items-center justify-center border border-[#FF9500]/30">
                  <AlertTriangle className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-black tracking-widest uppercase text-[#FF9500]">
                  ALERT
                </span>
              </div>
              <div className="mt-3 flex items-baseline justify-between gap-2">
                <span className="text-xs font-bold text-white/60 tracking-wider uppercase">
                  Issues Detected
                </span>
                <span className="text-2xl sm:text-3xl font-black text-[#FF9500] tracking-tight">
                  {companiesWithIssues}
                </span>
              </div>
            </button>
          </div>
        </section>

        {/* ─── Clear, Generous Separation between Status & Search ─── */}
        <div className="py-2">
          <div className="w-full border-t border-[#1e2836]/80" />
        </div>

        {/* ─── 2. SEARCH BAR AND FILTER UNDERNEATH ─── */}
        <section aria-label="Search and Filter Controls">
          <div className="p-4 sm:p-5 rounded-2xl bg-[#111922] border border-[#1e2836] flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4 shadow-md">
            {/* Search Input Box */}
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-white/40 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="text"
                placeholder="Search company name, IP address, or site user..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-9 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] focus:border-[#00C08B] focus:ring-1 focus:ring-[#00C08B] text-white placeholder-white/40 text-xs sm:text-sm outline-none transition-all"
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 hover:text-white"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            {/* Filter Pills */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
              <div className="hidden sm:flex items-center gap-1 text-[11px] font-bold text-white/40 mr-1 uppercase">
                <Filter className="w-3.5 h-3.5" />
                <span>Filter:</span>
              </div>

              {(
                [
                  { key: 'all', label: 'All', count: totalCompanies },
                  { key: 'active', label: 'Active', count: activeCompanies },
                  { key: 'blocked', label: 'Blocked', count: blockedCompanies },
                  { key: 'issues', label: 'Issues', count: companiesWithIssues },
                ] as const
              ).map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => setFilter(tab.key)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 shrink-0 cursor-pointer ${
                    filter === tab.key
                      ? 'bg-[#00C08B] text-[#060B11] shadow-md shadow-[#00C08B]/20'
                      : 'bg-[#0b1119] text-white/60 hover:text-white border border-[#1e2836]'
                  }`}
                >
                  <span>{tab.label}</span>
                  <span
                    className={`text-[10px] px-1.5 py-0.2 rounded-full font-black ${
                      filter === tab.key
                        ? 'bg-[#060B11]/20 text-[#060B11]'
                        : 'bg-white/10 text-white/60'
                    }`}
                  >
                    {tab.count}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </section>

        {/* ─── 3. COMPANIES LIST ─── */}
        {filteredCompanies.length === 0 ? (
          <div className="py-20 text-center rounded-2xl bg-[#111922] border border-[#1e2836]">
            <Inbox className="w-12 h-12 mx-auto text-white/20 mb-3" />
            <h3 className="text-base font-bold text-white/70">No companies found</h3>
            <p className="text-xs text-white/40 mt-1">
              {searchQuery || filter !== 'all'
                ? 'Try adjusting your search query or selected filter.'
                : 'Click "Add Company" in the header to register your first datacenter.'}
            </p>
          </div>
        ) : (
          <div className="space-y-6 sm:space-y-8">
            {filteredCompanies.map((company) => (
              <CompanyCard
                key={company.id}
                company={company}
                onToggleBlock={handleToggleBlock}
                onOpenAddAccount={(id) => setAccountModalCompanyId(id)}
                onDeleteAccount={handleDeleteAccount}
                onDeleteCompany={handleDeleteCompany}
              />
            ))}
          </div>
        )}
      </main>

      {/* Modals */}
      {showAddCompany && (
        <AddCompanyModal
          onClose={() => setShowAddCompany(false)}
          onAddCompany={handleAddCompany}
        />
      )}

      {accountModalCompanyId && targetAccountCompany && (
        <AddAccountModal
          companyId={accountModalCompanyId}
          companyName={targetAccountCompany.name}
          onClose={() => setAccountModalCompanyId(null)}
          onAddAccount={handleAddAccount}
        />
      )}

      {showSettings && (
        <SettingsModal
          currentEmail={recoveryEmail}
          onClose={() => setShowSettings(false)}
          onSaveEmail={handleSaveEmail}
        />
      )}

      {/* ─── Sign Out Confirmation Modal (Guaranteed perfectly centered on viewport) ─── */}
      {showSignOutConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
          <div className="w-full max-w-sm rounded-2xl bg-[#141d27] border border-[#1e2836] p-6 shadow-2xl">
            <div className="flex items-center gap-3.5 mb-4">
              <div className="w-10 h-10 rounded-xl bg-[#FF3B30]/15 text-[#FF3B30] border border-[#FF3B30]/30 flex items-center justify-center shrink-0">
                <LogOut className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-white text-base">Sign Out?</h3>
                <p className="text-xs text-white/50">Monitoring Gateway</p>
              </div>
            </div>

            <p className="text-xs text-white/70 mb-5 leading-relaxed">
              Are you sure you want to sign out? You will be returned to the login screen.
            </p>

            <div className="flex items-center justify-end gap-2.5">
              <button
                onClick={() => setShowSignOutConfirm(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white bg-[#1e2836] hover:bg-[#2a3a4e] transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  setShowSignOutConfirm(false);
                  handleSignOut();
                }}
                className="px-4 py-2 rounded-xl text-xs font-bold bg-[#FF3B30] hover:bg-[#ff5247] text-white transition-all shadow-lg shadow-[#FF3B30]/20 cursor-pointer"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
