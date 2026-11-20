import React, { useState } from 'react';
import { X, Edit, Terminal, UserCheck, Mail, Save } from 'lucide-react';
import { CompanyAccount } from '../types';
import { apiService } from '../services/apiService';

interface EditAccountModalProps {
  companyId: string;
  companyName: string;
  account: CompanyAccount;
  onClose: () => void;
  onUpdateAccount: (companyId: string, account: CompanyAccount) => void;
}

export const EditAccountModal: React.FC<EditAccountModalProps> = ({
  companyId,
  companyName,
  account,
  onClose,
  onUpdateAccount,
}) => {
  const [username, setUsername] = useState(account.username);
  const [email, setEmail] = useState(account.email || '');
  const [isRackConsole, setIsRackConsole] = useState(account.isRackConsole);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim()) {
      setError('Username is required');
      return;
    }
    const trimmedEmail = email.trim();
    if (trimmedEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      setError('Please enter a valid email address');
      return;
    }

    setSaving(true);
    setError('');

    if (companyId.startsWith('site-') && account.id.startsWith('member-')) {
      const siteId = parseInt(companyId.replace('site-', ''), 10);
      const memberUserId = parseInt(account.id.replace('member-', ''), 10);
      if (!isNaN(siteId) && !isNaN(memberUserId)) {
        const res = await apiService.updateSiteMemberEmail(siteId, memberUserId, trimmedEmail);
        if (!res.success) {
          setSaving(false);
          setError(res.message || 'Failed to save recovery email');
          return;
        }
      }
    }

    const updatedAcc: CompanyAccount = {
      ...account,
      username: username.trim(),
      email: trimmedEmail || undefined,
      isRackConsole,
    };

    onUpdateAccount(companyId, updatedAcc);
    setSaving(false);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
      <div className="w-full max-w-md rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl p-6">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-[#1e2836]">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-[#00C08B]/15 text-[#00C08B]">
              <Edit className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white">Edit Credentials</h3>
              <p className="text-xs text-white/50">{companyName}</p>
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
          <div className="mt-4 p-2.5 rounded-xl bg-[#FF3B30]/15 border border-[#FF3B30]/30 text-xs text-[#FF6961]">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="mt-5 space-y-4">
          {/* Account Type Selection */}
          <div>
            <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1.5">
              ACCOUNT TYPE
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setIsRackConsole(false)}
                className={`p-2.5 rounded-xl border flex items-center justify-center gap-2 text-xs font-bold transition-all cursor-pointer ${
                  !isRackConsole
                    ? 'bg-[#00C08B]/15 text-[#00C08B] border-[#00C08B]/40 shadow-sm'
                    : 'bg-[#0b1119] text-white/50 border-[#1e2836] hover:text-white'
                }`}
              >
                <UserCheck className="w-4 h-4" />
                Standard Account
              </button>
              <button
                type="button"
                onClick={() => setIsRackConsole(true)}
                className={`p-2.5 rounded-xl border flex items-center justify-center gap-2 text-xs font-bold transition-all cursor-pointer ${
                  isRackConsole
                    ? 'bg-[#00E5FF]/15 text-[#00E5FF] border-[#00E5FF]/40 shadow-sm'
                    : 'bg-[#0b1119] text-white/50 border-[#1e2836] hover:text-white'
                }`}
              >
                <Terminal className="w-4 h-4" />
                Rack Console
              </button>
            </div>
          </div>

          {/* Username */}
          <div>
            <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
              USERNAME *
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="Username"
              className="w-full px-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/20 focus:outline-none focus:border-[#00C08B] transition-colors"
            />
          </div>

          {/* Recovery Email */}
          <div>
            <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1">
              RECOVERY EMAIL (BACKUP FOR PASSWORD RESET)
            </label>
            <div className="relative">
              <Mail className="w-4 h-4 text-white/40 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="user@company.com"
                className="w-full pl-9 pr-3.5 py-2.5 rounded-xl bg-[#0b1119] border border-[#1e2836] text-white text-xs placeholder:text-white/25 focus:outline-none focus:border-[#00C08B] transition-colors font-mono"
              />
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center justify-end gap-3 pt-3 border-t border-[#1e2836]">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white bg-[#1e2836] hover:bg-[#2a3a4e] transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="px-4 py-2 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d69b] disabled:opacity-60 text-[#060B11] transition-all shadow-lg shadow-[#00C08B]/20 cursor-pointer flex items-center gap-1.5"
            >
              <Save className="w-4 h-4" />
              {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
