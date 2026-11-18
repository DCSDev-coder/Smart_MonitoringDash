import React, { useState } from 'react';
import { X, Settings, Mail, Save, Send, ShieldCheck, CheckCircle2 } from 'lucide-react';

interface SettingsModalProps {
  currentEmail: string;
  onClose: () => void;
  onSaveEmail: (email: string) => Promise<{ success: boolean; message?: string }>;
  onSendRecovery: () => Promise<{ success: boolean; message?: string }>;
  onChangePassword: (currentPassword: string, newPassword: string) => Promise<{ success: boolean; message?: string }>;
  onRequestUsernameCode: () => Promise<{ success: boolean; message?: string }>;
  onChangeUsername: (username: string, code: string) => Promise<{ success: boolean; message?: string }>;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  currentEmail,
  onClose,
  onSaveEmail,
  onSendRecovery,
  onChangePassword,
  onRequestUsernameCode,
  onChangeUsername,
}) => {
  const [email, setEmail] = useState(currentEmail);
  const [savedMsg, setSavedMsg] = useState(false);
  const [recoverySent, setRecoverySent] = useState(false);
  const [sending, setSending] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordMsg, setPasswordMsg] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [changingPassword, setChangingPassword] = useState(false);
  const [username, setUsername] = useState('');
  const [usernameCode, setUsernameCode] = useState('');
  const [usernameMsg, setUsernameMsg] = useState('');
  const [usernameError, setUsernameError] = useState('');
  const [requestingUsernameCode, setRequestingUsernameCode] = useState(false);
  const [changingUsername, setChangingUsername] = useState(false);

  React.useEffect(() => {
    setUsername('');
  }, [currentEmail]);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !email.includes('@')) {
      alert('Please enter a valid email address');
      return;
    }
    setEmailError('');
    const result = await onSaveEmail(email.trim());
    if (result.success) {
      setSavedMsg(true);
      setTimeout(() => setSavedMsg(false), 2500);
    } else {
      setEmailError(result.message || 'Failed to update recovery email');
    }
  };

  const handleSendRecoveryCode = async () => {
    if (!email.trim() || !email.includes('@')) {
      alert('Please enter a valid email address first');
      return;
    }
    setSending(true);
    const result = await onSendRecovery();
    setSending(false);
    if (result.success) {
      setRecoverySent(true);
    } else {
      setEmailError(result.message || 'Unable to send recovery code');
    }
  };

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError('');
    setPasswordMsg('');
    if (!currentPassword || newPassword.length < 8 || newPassword !== confirmPassword) {
      setPasswordError('Enter the current password, an 8+ character new password, and matching confirmation.');
      return;
    }
    setChangingPassword(true);
    const result = await onChangePassword(currentPassword, newPassword);
    setChangingPassword(false);
    if (result.success) {
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setPasswordMsg('Password changed successfully.');
    } else {
      setPasswordError(result.message || 'Failed to change password');
    }
  };

  const handleRequestUsernameCode = async () => {
    setUsernameError('');
    setRequestingUsernameCode(true);
    const result = await onRequestUsernameCode();
    setRequestingUsernameCode(false);
    if (result.success) setUsernameMsg(result.message || 'Verification code sent.');
    else setUsernameError(result.message || 'Unable to send verification code');
  };

  const handleChangeUsername = async (e: React.FormEvent) => {
    e.preventDefault();
    setUsernameError('');
    setUsernameMsg('');
    if (!/^[a-zA-Z0-9._-]{3,50}$/.test(username.trim()) || usernameCode.trim().length < 4) {
      setUsernameError('Enter a valid username and the verification code.');
      return;
    }
    setChangingUsername(true);
    const result = await onChangeUsername(username, usernameCode);
    setChangingUsername(false);
    if (result.success) {
      setUsernameCode('');
      setUsernameMsg('Username changed successfully.');
    } else {
      setUsernameError(result.message || 'Failed to change username');
    }
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
            Password reset links will be sent to this email if you forget your password.
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
            {emailError && <p className="text-xs text-[#FF6961]">{emailError}</p>}

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
                onClick={handleSendRecoveryCode}
                disabled={sending}
                className="flex-1 py-2 px-3 rounded-xl bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer shadow-lg shadow-[#00C08B]/20"
              >
                <Send className="w-3.5 h-3.5" />
                {sending ? 'Sending...' : 'Send Recovery'}
              </button>
            </div>
          </form>
        </div>

        <div className="mt-4 p-4 rounded-xl bg-[#0b1119] border border-[#1e2836] space-y-3">
          <h4 className="text-xs font-bold tracking-wider uppercase text-[#00E5FF]">Change Password</h4>
          <form onSubmit={handleChangePassword} className="space-y-2.5">
            <input type="password" value={currentPassword} onChange={(e) => setCurrentPassword(e.target.value)} placeholder="Current password" className="w-full px-3.5 py-2.5 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]" />
            <input type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} placeholder="New password (8+ characters)" className="w-full px-3.5 py-2.5 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]" />
            <input type="password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} placeholder="Confirm new password" className="w-full px-3.5 py-2.5 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]" />
            {passwordError && <p className="text-xs text-[#FF6961]">{passwordError}</p>}
            {passwordMsg && <p className="text-xs text-[#00C08B]">{passwordMsg}</p>}
            <button type="submit" disabled={changingPassword} className="w-full py-2 rounded-xl bg-[#1e2836] hover:bg-[#2a3a4e] text-xs font-bold text-white disabled:opacity-60">
              {changingPassword ? 'Changing...' : 'Change Password'}
            </button>
          </form>
        </div>

        <div className="mt-4 p-4 rounded-xl bg-[#0b1119] border border-[#1e2836] space-y-3">
          <h4 className="text-xs font-bold tracking-wider uppercase text-[#00E5FF]">Change Username</h4>
          <form onSubmit={handleChangeUsername} className="space-y-2.5">
            <input type="text" value={username} onChange={(e) => setUsername(e.target.value)} placeholder="New username" className="w-full px-3.5 py-2.5 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]" />
            <div className="flex gap-2">
              <input type="text" inputMode="numeric" value={usernameCode} onChange={(e) => setUsernameCode(e.target.value)} placeholder="Verification code" className="min-w-0 flex-1 px-3.5 py-2.5 bg-[#141d27] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]" />
              <button type="button" onClick={handleRequestUsernameCode} disabled={requestingUsernameCode} className="px-3 rounded-xl bg-[#1e2836] text-xs font-bold text-white disabled:opacity-60">{requestingUsernameCode ? 'Sending...' : 'Send Code'}</button>
            </div>
            {usernameError && <p className="text-xs text-[#FF6961]">{usernameError}</p>}
            {usernameMsg && <p className="text-xs text-[#00C08B]">{usernameMsg}</p>}
            <button type="submit" disabled={changingUsername} className="w-full py-2 rounded-xl bg-[#1e2836] hover:bg-[#2a3a4e] text-xs font-bold text-white disabled:opacity-60">{changingUsername ? 'Changing...' : 'Change Username'}</button>
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
          <span>Passwords are sent to the portal over HTTPS and are not stored in this dashboard.</span>
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
