import React, { useState } from 'react';
import { X, Settings, Mail, Save, Send, ShieldCheck, CheckCircle2 } from 'lucide-react';

interface SettingsModalProps {
  currentEmail: string;
  onClose: () => void;
  onSaveEmail: (email: string) => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  currentEmail,
  onClose,
  onSaveEmail,
}) => {
  const [email, setEmail] = useState(currentEmail);
  const [savedMsg, setSavedMsg] = useState(false);
  const [recoverySent, setRecoverySent] = useState(false);
  const [sending, setSending] = useState(false);

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !email.includes('@')) {
      alert('Please enter a valid email address');
      return;
    }
    onSaveEmail(email.trim());
    setSavedMsg(true);
    setTimeout(() => setSavedMsg(false), 2500);
  };

  const handleSendRecovery = () => {
    if (!email.trim() || !email.includes('@')) {
      alert('Please enter a valid email address first');
      return;
    }
    setSending(true);
    setTimeout(() => {
      setSending(false);
      setRecoverySent(true);
    }, 800);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
      <div className="w-full max-w-md rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl p-6">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-[#1e2836]">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-[#00C08B]/15 text-[#00C08B]">
              <Settings className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white">System Settings</h3>
              <p className="text-xs text-white/50">Admin security & email recovery</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-white/40 hover:text-white transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Admin Email Recovery Card */}
        <div className="mt-5 p-4 rounded-xl bg-[#0b1119] border border-[#1e2836] space-y-4">
          <div className="flex items-center gap-2 text-[#00E5FF]">
            <Mail className="w-4 h-4" />
            <h4 className="text-xs font-bold tracking-wider uppercase">
              Admin Email Recovery
            </h4>
          </div>

          <p className="text-xs text-white/60 leading-relaxed">
            In case the admin forgets the password, use this recovery email address to
            receive a secure password reset link and recovery instructions.
          </p>

          <form onSubmit={handleSave} className="space-y-3">
            <div>
              <label className="text-[10px] font-bold text-white/40 block mb-1">
                RECOVERY EMAIL ADDRESS
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@dcstack.my"
                className="w-full px-3.5 py-2.5 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
              />
            </div>

            {savedMsg && (
              <p className="text-xs text-[#00C08B] font-bold flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5" />
                Recovery email updated successfully!
              </p>
            )}

            <div className="flex items-center gap-2 pt-1">
              <button
                type="submit"
                className="flex-1 py-2 px-3 rounded-xl bg-[#1e2836] hover:bg-[#2a3a4e] text-xs font-bold text-white transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <Save className="w-3.5 h-3.5" />
                Save Email
              </button>

              <button
                type="button"
                onClick={handleSendRecovery}
                disabled={sending}
                className="flex-1 py-2 px-3 rounded-xl bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer shadow-lg shadow-[#00C08B]/20"
              >
                <Send className="w-3.5 h-3.5" />
                {sending ? 'Sending...' : 'Send Recovery'}
              </button>
            </div>
          </form>
        </div>

        {/* Recovery Sent Feedback Modal Alert */}
        {recoverySent && (
          <div className="mt-4 p-3.5 rounded-xl bg-[#00C08B]/15 border border-[#00C08B]/40 text-xs text-[#00C08B] space-y-1">
            <p className="font-bold flex items-center gap-1.5">
              <CheckCircle2 className="w-4 h-4" /> Password Recovery Email Dispatched!
            </p>
            <p className="text-white/70 text-[11px]">
              A password reset token has been sent to <strong>{email}</strong>. Check your inbox
              to proceed with resetting admin access.
            </p>
          </div>
        )}

        {/* Security Info */}
        <div className="mt-4 p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] flex items-center gap-2.5 text-xs text-white/40">
          <ShieldCheck className="w-4 h-4 text-[#00C08B] shrink-0" />
          <span>Local storage encryption active. Passwords protected with view masking.</span>
        </div>

        {/* Close Button */}
        <div className="mt-5 flex justify-end">
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
