import React, { useState } from 'react';
import {
  Building2,
  MoreVertical,
  KeyRound,
  Eye,
  EyeOff,
  Copy,
  Check,
  Ban,
  CheckCircle,
  AlertTriangle,
  Flame,
  Droplets,
  BatteryCharging,
  Cpu,
  Thermometer,
  Wind,
  Terminal,
  UserCheck,
  Plus,
  Trash2,
} from 'lucide-react';
import { CompanyItem, MonitorIssueType } from '../types';
import { SiteCredentialsModal } from './SiteCredentialsModal';

interface CompanyCardProps {
  company: CompanyItem;
  onToggleBlock: (companyId: string) => void;
  onOpenAddAccount: (companyId: string) => void;
  onDeleteAccount: (companyId: string, accountId: string) => void;
  onDeleteCompany: (companyId: string) => void;
}

export const CompanyCard: React.FC<CompanyCardProps> = ({
  company,
  onToggleBlock,
  onOpenAddAccount,
  onDeleteAccount,
  onDeleteCompany,
}) => {
  const [showSiteCredentials, setShowSiteCredentials] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  // Default to true so passwords are shown directly as requested
  const [revealedAccountPasses, setRevealedAccountPasses] = useState<Record<string, boolean>>({});
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [showConfirmBlock, setShowConfirmBlock] = useState(false);
  const [showConfirmDelete, setShowConfirmDelete] = useState(false);

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const toggleAccountPass = (id: string) => {
    setRevealedAccountPasses((prev) => ({
      ...prev,
      // If undefined, it was visible, toggling makes it masked
      [id]: prev[id] === undefined ? false : !prev[id],
    }));
  };

  // Helper to parse dates into calendar tear-off format
  const parseDateParts = (dateStr: string) => {
    if (!dateStr) return { month: 'JAN', day: '01', year: '2026' };
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      const year = parts[0];
      const monthNum = parseInt(parts[1], 10);
      const day = parts[2];
      const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      return {
        month: months[monthNum - 1] || 'MTH',
        day: day,
        year: year,
      };
    }
    return { month: 'MTH', day: '01', year: '2026' };
  };

  const lastDateParts = parseDateParts(company.lastService);
  const nextDateParts = parseDateParts(company.nextService);

  // Calculate days difference for Expected service
  const nextDate = new Date(company.nextService);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  nextDate.setHours(0, 0, 0, 0);
  const diffMs = nextDate.getTime() - today.getTime();
  const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

  const isNextOverdue = diffDays < 0;
  // Near the expected: within 30 days
  const isNearExpected = diffDays >= 0 && diffDays <= 30;
  const isExpectedRed = isNextOverdue || isNearExpected; // RED if near expected or overdue

  // Helper icon for each telemetry issue
  const renderIssueIcon = (issue: MonitorIssueType) => {
    switch (issue) {
      case 'Unsecure AC':
        return <Wind className="w-3.5 h-3.5" />;
      case 'T.H':
        return <Thermometer className="w-3.5 h-3.5" />;
      case 'Power':
        return <AlertTriangle className="w-3.5 h-3.5" />;
      case 'UPS':
        return <BatteryCharging className="w-3.5 h-3.5" />;
      case 'Smoke':
        return <Flame className="w-3.5 h-3.5" />;
      case 'Leak':
        return <Droplets className="w-3.5 h-3.5" />;
      case 'PDU':
        return <Cpu className="w-3.5 h-3.5" />;
      default:
        return <AlertTriangle className="w-3.5 h-3.5" />;
    }
  };

  return (
    <div
      className={`rounded-2xl bg-[#111922] border transition-all duration-300 shadow-xl overflow-hidden ${
        company.isBlocked
          ? 'border-[#FF3B30]/60 shadow-[#FF3B30]/5 ring-1 ring-[#FF3B30]/40'
          : company.activeIssues.length > 0
          ? 'border-[#FF9500]/40 shadow-black/40'
          : 'border-[#1e2836] hover:border-[#2a3a4e] shadow-black/40'
      }`}
    >
      {/* ─── Top Header: Company Name & Status on Left, PUE & 3-Dots on Far Right ─── */}
      <div className="p-6 sm:p-8 pb-5">
        <div className="flex items-center justify-between gap-4">
          {/* Left: Building Icon, Company Name, Status Badge (Active / Blocked) */}
          <div className="flex items-center gap-4 flex-wrap min-w-0">
            <div
              className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${
                company.isBlocked
                  ? 'bg-[#FF3B30]/15 text-[#FF3B30] border border-[#FF3B30]/30'
                  : 'bg-[#00C08B]/15 text-[#00C08B] border border-[#00C08B]/30'
              }`}
            >
              <Building2 className="w-5 h-5" />
            </div>

            <div className="flex flex-wrap items-center gap-3.5 min-w-0">
              {/* Company Name */}
              <h2 className="text-xl sm:text-2xl font-extrabold text-white tracking-wide truncate">
                {company.name}
              </h2>

              {/* Status Badge: Active or Blocked (Interactive) */}
              <button
                onClick={() => setShowConfirmBlock(true)}
                title="Click to toggle Block / Active status"
                className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-extrabold tracking-wider border cursor-pointer transition-all hover:scale-102 active:scale-95 ${
                  company.isBlocked
                    ? 'bg-[#FF3B30]/20 text-[#FF6961] border-[#FF3B30]/40 hover:bg-[#FF3B30]/30'
                    : 'bg-[#00C08B]/20 text-[#00C08B] border-[#00C08B]/40 hover:bg-[#00C08B]/30'
                }`}
              >
                <span
                  className={`w-2 h-2 rounded-full ${
                    company.isBlocked ? 'bg-[#FF3B30]' : 'bg-[#00C08B]'
                  }`}
                />
                {company.isBlocked ? 'BLOCKED' : 'ACTIVE'}
              </button>
            </div>
          </div>

          {/* Far Right: Circular PUE and 3-Dotted Button ("See More") */}
          <div className="flex items-center gap-3.5 shrink-0">
            {/* ─── PUE IN A CIRCLE ON THE FAR RIGHT (Enlarged) ─── */}
            <div
              className={`w-16 h-16 sm:w-18 sm:h-18 rounded-full border-[2.5px] flex flex-col items-center justify-center shrink-0 shadow-lg transition-transform hover:scale-105 ${
                company.pue <= 1.3
                  ? 'border-[#00C08B] bg-[#00C08B]/15 text-[#00C08B] shadow-[#00C08B]/15'
                  : company.pue <= 1.5
                  ? 'border-[#FF9500] bg-[#FF9500]/15 text-[#FF9500] shadow-[#FF9500]/15'
                  : 'border-[#FF3B30] bg-[#FF3B30]/15 text-[#FF3B30] shadow-[#FF3B30]/15'
              }`}
              title={`PUE: ${company.pue.toFixed(2)} (${
                company.pue <= 1.3 ? 'Optimal' : company.pue <= 1.5 ? 'Moderate' : 'High'
              })`}
            >
              <span className="text-[10px] sm:text-xs font-bold tracking-wider text-white/60 leading-none">
                PUE
              </span>
              <span className="text-base sm:text-lg font-black tracking-tight leading-none mt-1">
                {company.pue.toFixed(2)}
              </span>
            </div>

            {/* ─── 3 DOTTED BUTTON TO SEE MORE ─── */}
            <div className="relative">
              <button
                onClick={() => setShowMenu(!showMenu)}
                className="p-3 rounded-xl bg-[#0b1119] hover:bg-[#1a2330] border border-[#1e2836] text-white/70 hover:text-white transition-colors cursor-pointer shadow-sm"
                title="3 Dots: See More Site Details"
              >
                <MoreVertical className="w-4 h-4 sm:w-5 sm:h-5" />
              </button>

              {/* 3 Dots Dropdown Menu */}
              {showMenu && (
                <>
                  <div
                    className="fixed inset-0 z-40"
                    onClick={() => setShowMenu(false)}
                  />
                  <div className="absolute right-0 top-full mt-2 w-60 rounded-xl bg-[#141d27] border border-[#1e2836] shadow-2xl p-1.5 z-50 animate-fadeIn">
                    <button
                      onClick={() => {
                        setShowMenu(false);
                        setShowSiteCredentials(true);
                      }}
                      className="w-full px-3 py-2 rounded-lg text-left text-xs font-semibold text-white/90 hover:text-white hover:bg-[#1e2836] flex items-center gap-2 transition-colors cursor-pointer"
                    >
                      <KeyRound className="w-4 h-4 text-[#00E5FF]" />
                      <span>See More (IPs & Site Login)</span>
                    </button>
                    <div className="my-1 border-t border-[#1e2836]" />
                    <button
                      onClick={() => {
                        setShowMenu(false);
                        setShowConfirmBlock(true);
                      }}
                      className={`w-full px-3 py-2 rounded-lg text-left text-xs font-semibold flex items-center gap-2 transition-colors cursor-pointer ${
                        company.isBlocked
                          ? 'text-[#00C08B] hover:bg-[#00C08B]/15'
                          : 'text-[#FF9500] hover:bg-[#FF9500]/15'
                      }`}
                    >
                      {company.isBlocked ? (
                        <>
                          <CheckCircle className="w-4 h-4" />
                          <span>Unblock Datacenter</span>
                        </>
                      ) : (
                        <>
                          <Ban className="w-4 h-4" />
                          <span>Block Site (Unpaid)</span>
                        </>
                      )}
                    </button>
                    <div className="my-1 border-t border-[#1e2836]" />
                    <button
                      onClick={() => {
                        setShowMenu(false);
                        setShowConfirmDelete(true);
                      }}
                      className="w-full px-3 py-2 rounded-lg text-left text-xs font-semibold text-[#FF6961] hover:bg-[#FF3B30]/15 flex items-center gap-2 transition-colors cursor-pointer"
                    >
                      <Trash2 className="w-4 h-4" />
                      <span>Delete Company</span>
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>

        {/* ─── Last Service Date, Next Service Date, and Issue: Beside It ─── */}
        <div className="mt-6 pt-5 border-t border-[#1e2836]/80 flex flex-wrap items-center justify-between gap-4">
          {/* Service Schedule Dates: Distinct Mini Calendar Look (Red if near expected/overdue, Green if okay) */}
          <div className="flex flex-wrap items-center gap-4 sm:gap-6">
            {/* ─── 1. LAST SERVICE: Completed Historical Calendar ─── */}
            <div className="flex items-center gap-3.5 px-3.5 py-2.5 sm:px-4 sm:py-3 rounded-2xl bg-[#0b1119] border border-[#1e2836] shadow-md hover:border-[#2a3a4e] transition-all">
              {/* Calendar Sheet: Neutral Slate Style with Binder Rings */}
              <div className="relative w-11 h-13 sm:w-12 sm:h-14 rounded-xl overflow-hidden bg-[#141d27] border border-slate-700/70 shadow-sm flex flex-col items-center shrink-0">
                {/* Spiral/Binder ring indicators */}
                <div className="absolute top-1 left-2 w-1 h-1 rounded-full bg-slate-900 border border-white/20 z-10" />
                <div className="absolute top-1 right-2 w-1 h-1 rounded-full bg-slate-900 border border-white/20 z-10" />

                {/* Header: Month in slate tone */}
                <div className="w-full pt-1 pb-0.5 text-center text-[9px] font-black uppercase tracking-wider text-slate-300 bg-[#243242]">
                  {lastDateParts.month}
                </div>

                {/* Body: Day number & Year */}
                <div className="flex-1 flex flex-col items-center justify-center -mt-0.5">
                  <span className="text-base sm:text-lg font-black text-white leading-none">
                    {lastDateParts.day}
                  </span>
                  <span className="text-[8px] font-bold text-white/40 leading-none mt-0.5">
                    {lastDateParts.year}
                  </span>
                </div>
              </div>

              {/* Text Info */}
              <div className="min-w-0 pr-1">
                <div className="flex items-center gap-1.5">
                  <span className="text-[10px] font-black text-white/40 uppercase tracking-wider">
                    LAST SERVICE
                  </span>
                  <span className="text-[9px] px-1.5 py-0.2 rounded-md font-bold bg-white/10 text-white/60">
                    Past
                  </span>
                </div>
                <span className="text-xs sm:text-sm font-extrabold text-white/90 tracking-wider block mt-0.5 font-mono">
                  {company.lastService}
                </span>
              </div>
            </div>

            {/* ─── 2. EXPECTED SERVICE: Active Forward Calendar (Red if near expected, Green if okay) ─── */}
            <div
              className={`flex items-center gap-3.5 px-3.5 py-2.5 sm:px-4 sm:py-3 rounded-2xl bg-[#0b1119] border shadow-md transition-all ${
                isExpectedRed
                  ? 'border-[#FF3B30]/60 shadow-[#FF3B30]/10 ring-1 ring-[#FF3B30]/30'
                  : 'border-[#00C08B]/50 shadow-[#00C08B]/10 ring-1 ring-[#00C08B]/20'
              }`}
            >
              {/* Calendar Sheet: Red if near expected / overdue, Green if okay */}
              <div
                className={`relative w-11 h-13 sm:w-12 sm:h-14 rounded-xl overflow-hidden bg-[#141d27] border shadow-sm flex flex-col items-center shrink-0 ${
                  isExpectedRed
                    ? 'border-[#FF3B30]/60 shadow-sm shadow-[#FF3B30]/20'
                    : 'border-[#00C08B]/60 shadow-sm shadow-[#00C08B]/20'
                }`}
              >
                {/* Spiral/Binder ring indicators */}
                <div className="absolute top-1 left-2 w-1 h-1 rounded-full bg-black/60 border border-white/20 z-10" />
                <div className="absolute top-1 right-2 w-1 h-1 rounded-full bg-black/60 border border-white/20 z-10" />

                {/* Header: Month in Red or Green */}
                <div
                  className={`w-full pt-1 pb-0.5 text-center text-[9px] font-black uppercase tracking-wider text-white ${
                    isExpectedRed ? 'bg-[#FF3B30]' : 'bg-[#00C08B]'
                  }`}
                >
                  {nextDateParts.month}
                </div>

                {/* Body: Day number in vibrant color */}
                <div className="flex-1 flex flex-col items-center justify-center -mt-0.5">
                  <span
                    className={`text-base sm:text-lg font-black leading-none ${
                      isExpectedRed ? 'text-[#FF6961]' : 'text-[#00C08B]'
                    }`}
                  >
                    {nextDateParts.day}
                  </span>
                  <span className="text-[8px] font-bold text-white/40 leading-none mt-0.5">
                    {nextDateParts.year}
                  </span>
                </div>
              </div>

              {/* Text Info */}
              <div className="min-w-0 pr-1">
                <div className="flex items-center gap-1.5 flex-wrap">
                  <span
                    className={`text-[10px] font-black uppercase tracking-wider ${
                      isExpectedRed ? 'text-[#FF6961]' : 'text-[#00C08B]'
                    }`}
                  >
                    EXPECTED SERVICE
                  </span>
                  {/* Status Badge: Red if near expected or overdue, Green if okay */}
                  <span
                    className={`text-[9px] px-1.5 py-0.2 rounded-md font-extrabold ${
                      isNextOverdue
                        ? 'bg-[#FF3B30]/20 text-[#FF6961] border border-[#FF3B30]/40'
                        : isNearExpected
                        ? 'bg-[#FF3B30]/20 text-[#FF6961] border border-[#FF3B30]/40'
                        : 'bg-[#00C08B]/20 text-[#00C08B] border border-[#00C08B]/40'
                    }`}
                  >
                    {isNextOverdue
                      ? `Overdue (${Math.abs(diffDays)}d ago)`
                      : isNearExpected
                      ? `Near (${diffDays}d left)`
                      : `Okay (${diffDays}d left)`}
                  </span>
                </div>
                <span
                  className={`text-xs sm:text-sm font-extrabold tracking-wider block mt-0.5 font-mono ${
                    isExpectedRed ? 'text-[#FF6961]' : 'text-white'
                  }`}
                >
                  {company.nextService}
                </span>
              </div>
            </div>
          </div>

          {/* ─── Issue: Beside It (Only shows active issues, or 'None') ─── */}
          <div className="flex flex-wrap items-center gap-2.5">
            <span className="text-xs font-bold text-white/50 tracking-wider">
              ISSUE:
            </span>

            {company.activeIssues.length === 0 ? (
              // When there are no issues -> display "None"
              <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#00C08B]/15 text-[#00C08B] border border-[#00C08B]/30 text-xs font-bold">
                <CheckCircle className="w-3.5 h-3.5" />
                None
              </span>
            ) : (
              // When there are issues -> ONLY display the ones that have issues!
              company.activeIssues.map((issue) => (
                <span
                  key={issue}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#FF3B30]/15 text-[#FF6961] border border-[#FF3B30]/40 text-xs font-bold animate-pulse"
                >
                  {renderIssueIcon(issue)}
                  {issue}
                </span>
              ))
            )}
          </div>
        </div>
      </div>

      {/* ─── Under Each Company: Accounts & Rack Consoles (Showing Username & Password) ─── */}
      <div className="bg-[#0b1119] px-6 sm:px-8 py-5 sm:py-6 border-t border-[#1e2836]">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <span className="text-xs font-bold text-white/70 tracking-wider uppercase">
              Accounts & Rack Consoles ({company.accounts.length})
            </span>
          </div>
          <button
            onClick={() => onOpenAddAccount(company.id)}
            className="inline-flex items-center gap-1 text-xs font-bold text-[#00C08B] hover:text-[#00d89c] transition-colors cursor-pointer"
          >
            <Plus className="w-3.5 h-3.5 stroke-[3]" />
            Add User / Console
          </button>
        </div>

        {company.accounts.length === 0 ? (
          <p className="text-xs text-white/35 italic py-2">
            No accounts or rack consoles created yet. Click above to add one.
          </p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {company.accounts.map((acc) => {
              // Default to revealed (true) unless explicitly toggled off
              const isRevealed = revealedAccountPasses[acc.id] !== false;
              return (
                <div
                  key={acc.id}
                  className={`p-3.5 sm:p-4 rounded-xl bg-[#141d27] border flex items-center justify-between gap-3 text-xs transition-colors ${
                    acc.isRackConsole
                      ? 'border-[#00E5FF]/30 hover:border-[#00E5FF]/50'
                      : 'border-[#1e2836] hover:border-[#2a3a4e]'
                  }`}
                >
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div
                      className={`p-2 rounded-lg shrink-0 ${
                        acc.isRackConsole
                          ? 'bg-[#00E5FF]/15 text-[#00E5FF]'
                          : 'bg-[#00C08B]/15 text-[#00C08B]'
                      }`}
                    >
                      {acc.isRackConsole ? (
                        <Terminal className="w-4 h-4" />
                      ) : (
                        <UserCheck className="w-4 h-4" />
                      )}
                    </div>

                    <div className="min-w-0 flex-1 space-y-1">
                      {/* Account Type and Username */}
                      <div className="flex items-center gap-2">
                        <span
                          className={`text-[9px] font-extrabold px-1.5 py-0.5 rounded border uppercase tracking-wider ${
                            acc.isRackConsole
                              ? 'bg-[#00E5FF]/15 text-[#00E5FF] border-[#00E5FF]/30'
                              : 'bg-white/10 text-white/80 border-white/15'
                          }`}
                        >
                          {acc.isRackConsole ? 'Rack Console' : 'Account'}
                        </span>
                        <span className="font-extrabold text-white text-xs truncate">
                          {acc.username}
                        </span>
                      </div>

                      {/* Password: Shown clearly */}
                      <div className="text-xs text-white/60 flex items-center gap-1.5 font-mono">
                        <span className="text-white/40">Password:</span>
                        <span className={isRevealed ? 'text-[#00C08B] font-bold select-all' : 'text-white/50'}>
                          {isRevealed ? acc.password : '••••••••'}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Actions for this account */}
                  <div className="flex items-center gap-1 shrink-0">
                    <button
                      onClick={() => toggleAccountPass(acc.id)}
                      className="p-1.5 rounded-lg bg-[#0b1119] text-white/40 hover:text-white transition-colors cursor-pointer"
                      title={isRevealed ? 'Mask Password' : 'Show Password'}
                    >
                      {isRevealed ? (
                        <EyeOff className="w-3.5 h-3.5 text-white/70" />
                      ) : (
                        <Eye className="w-3.5 h-3.5" />
                      )}
                    </button>
                    <button
                      onClick={() => copyToClipboard(acc.password, `accPass-${acc.id}`)}
                      className="p-1.5 rounded-lg bg-[#0b1119] text-white/40 hover:text-white transition-colors cursor-pointer"
                      title="Copy Password"
                    >
                      {copiedKey === `accPass-${acc.id}` ? (
                        <Check className="w-3.5 h-3.5 text-[#00C08B]" />
                      ) : (
                        <Copy className="w-3.5 h-3.5" />
                      )}
                    </button>
                    <button
                      onClick={() => onDeleteAccount(company.id, acc.id)}
                      className="p-1.5 rounded-lg bg-[#0b1119] text-white/40 hover:text-[#FF3B30] transition-colors cursor-pointer"
                      title="Delete Account"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ─── Site Credentials Modal (Open IP, Local IP, Site User, Site Password) ─── */}
      {showSiteCredentials && (
        <SiteCredentialsModal
          company={company}
          onClose={() => setShowSiteCredentials(false)}
        />
      )}

      {/* Confirmation Modal: Block / Unblock Site */}
      {showConfirmBlock && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
          <div className="w-full max-w-sm rounded-2xl bg-[#141d27] border border-[#1e2836] p-6 shadow-2xl">
            <div className="flex items-center gap-3 mb-4">
              <div
                className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                  company.isBlocked
                    ? 'bg-[#00C08B]/20 text-[#00C08B]'
                    : 'bg-[#FF3B30]/20 text-[#FF3B30]'
                }`}
              >
                {company.isBlocked ? (
                  <CheckCircle className="w-5 h-5" />
                ) : (
                  <Ban className="w-5 h-5" />
                )}
              </div>
              <div>
                <h3 className="font-bold text-white text-base">
                  {company.isBlocked ? 'Unblock Datacenter?' : 'Block Datacenter?'}
                </h3>
                <p className="text-xs text-white/50">{company.name}</p>
              </div>
            </div>

            <p className="text-xs text-white/70 mb-5 leading-relaxed">
              {company.isBlocked
                ? 'This will restore full site access, rack console permissions, and normal operations.'
                : 'Blocking will immediately suspend site access and console logins due to outstanding payment.'}
            </p>

            <div className="flex items-center justify-end gap-2.5">
              <button
                onClick={() => setShowConfirmBlock(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white bg-[#1e2836] hover:bg-[#2a3a4e] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  onToggleBlock(company.id);
                  setShowConfirmBlock(false);
                }}
                className={`px-4 py-2 rounded-xl text-xs font-bold transition-all shadow-lg ${
                  company.isBlocked
                    ? 'bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11]'
                    : 'bg-[#FF3B30] hover:bg-[#ff5247] text-white'
                }`}
              >
                {company.isBlocked ? 'Confirm Unblock' : 'Confirm Block'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Modal: Delete Company */}
      {showConfirmDelete && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
          <div className="w-full max-w-sm rounded-2xl bg-[#141d27] border border-[#FF3B30]/30 p-6 shadow-2xl">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-xl bg-[#FF3B30]/20 text-[#FF3B30] flex items-center justify-center">
                <Trash2 className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-white text-base">Delete Company</h3>
                <p className="text-xs text-white/50">{company.name}</p>
              </div>
            </div>

            <p className="text-xs text-white/70 mb-5 leading-relaxed">
              Are you sure you want to remove <span className="font-bold text-white">{company.name}</span>? All associated credentials and consoles will be permanently deleted.
            </p>

            <div className="flex items-center justify-end gap-2.5">
              <button
                onClick={() => setShowConfirmDelete(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white bg-[#1e2836] hover:bg-[#2a3a4e] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  onDeleteCompany(company.id);
                  setShowConfirmDelete(false);
                }}
                className="px-4 py-2 rounded-xl text-xs font-bold bg-[#FF3B30] hover:bg-[#ff5247] text-white transition-all shadow-lg shadow-[#FF3B30]/20"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
