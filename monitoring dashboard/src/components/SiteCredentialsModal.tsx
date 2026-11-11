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
} from 'lucide-react';
import { CompanyItem } from '../types';

interface SiteCredentialsModalProps {
  company: CompanyItem;
  onClose: () => void;
  onOpenEdit?: () => void;
}

export const SiteCredentialsModal: React.FC<SiteCredentialsModalProps> = ({
  company,
  onClose,
  onOpenEdit,
}) => {
  const [showPassword, setShowPassword] = useState(false);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
      <div className="w-full max-w-md rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl p-6">
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

        {/* Credentials List */}
        <div className="mt-5 space-y-3">
          {/* Open IP */}
          <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Globe className="w-4 h-4 text-[#00E5FF] shrink-0" />
              <div>
                <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                  OPEN IP (PUBLIC WAN)
                </span>
                <span className="text-xs font-semibold text-white">
                  {company.openIp}
                </span>
              </div>
            </div>
            <button
              onClick={() => copyToClipboard(company.openIp, 'openIp')}
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
          <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Router className="w-4 h-4 text-[#00E5FF] shrink-0" />
              <div>
                <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                  LOCAL IP (INTERNAL LAN)
                </span>
                <span className="text-xs font-semibold text-white">
                  {company.localIp}
                </span>
              </div>
            </div>
            <button
              onClick={() => copyToClipboard(company.localIp, 'localIp')}
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

          {/* Site User */}
          <div className="p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center justify-between">
            <div className="flex items-center gap-3">
              <User className="w-4 h-4 text-[#00C08B] shrink-0" />
              <div>
                <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                  SITE USER
                </span>
                <span className="text-xs font-semibold text-white">
                  {company.siteUser}
                </span>
              </div>
            </div>
            <button
              onClick={() => copyToClipboard(company.siteUser, 'siteUser')}
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
            <div className="flex items-center gap-3">
              <Key className="w-4 h-4 text-[#FF9500] shrink-0" />
              <div>
                <span className="text-[10px] font-bold text-white/40 tracking-wider block">
                  SITE PASSWORD
                </span>
                <span className="text-xs font-semibold text-white font-mono">
                  {showPassword ? company.sitePassword : '••••••••••••'}
                </span>
              </div>
            </div>
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setShowPassword(!showPassword)}
                className="p-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white/50 hover:text-white transition-colors cursor-pointer"
                title={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? (
                  <EyeOff className="w-3.5 h-3.5 text-white/80" />
                ) : (
                  <Eye className="w-3.5 h-3.5" />
                )}
              </button>
              <button
                onClick={() => copyToClipboard(company.sitePassword, 'sitePass')}
                className="p-1.5 rounded-lg bg-[#141d27] border border-[#1e2836] text-white/50 hover:text-white transition-colors cursor-pointer flex items-center gap-1 text-[11px]"
              >
                {copiedKey === 'sitePass' ? (
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
        <div className="mt-5 pt-4 border-t border-[#1e2836] flex items-center justify-between">
          {onOpenEdit ? (
            <button
              onClick={() => {
                onClose();
                onOpenEdit();
              }}
              className="px-4 py-2 rounded-xl text-xs font-bold bg-[#00C08B]/15 hover:bg-[#00C08B]/25 text-[#00C08B] border border-[#00C08B]/30 transition-colors cursor-pointer flex items-center gap-1.5"
            >
              <Edit3 className="w-3.5 h-3.5" />
              <span>Edit Details</span>
            </button>
          ) : <div />}
          <button
            onClick={onClose}
            className="px-5 py-2 rounded-xl text-xs font-bold bg-[#1e2836] hover:bg-[#2a3a4e] text-white transition-colors cursor-pointer"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
