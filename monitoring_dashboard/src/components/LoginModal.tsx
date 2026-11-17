import React, { useState } from 'react';
import { Lock, User, Eye, EyeOff, Mail, ArrowRight, CheckCircle2, Loader2 } from 'lucide-react';
import { AnimatedDcsLogo } from './AnimatedDcsLogo';
import { apiService } from '../services/apiService';

interface LoginModalProps {
  onLogin: (username: string, rememberMe?: boolean) => void;
  recoveryEmail: string;
}

export const LoginModal: React.FC<LoginModalProps> = ({ onLogin, recoveryEmail }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showForgotModal, setShowForgotModal] = useState(false);
  const [recoveryIdentifier, setRecoveryIdentifier] = useState('');
  const [recoveryCode, setRecoveryCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [recoveryStep, setRecoveryStep] = useState<'request' | 'verify' | 'done'>('request');
  const [recoveryStatus, setRecoveryStatus] = useState('');
  const [recoveryError, setRecoveryError] = useState('');
  const [recoveryLoading, setRecoveryLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      setError('Please enter both username and password');
      return;
    }
    setError('');
    setLoading(true);

    try {
      // Connect and authenticate against live DCStack Portal API
      const res = await apiService.login(username.trim(), password.trim(), rememberMe);
      if (res.success) {
        onLogin(username.trim(), rememberMe);
        return;
      }

      setError(res.message || 'Invalid username or password');
    } catch {
      setError('Failed to connect to DCStack Portal API.');
    } finally {
      setLoading(false);
    }
  };

  const handleSendRecoveryCode = async (e: React.FormEvent) => {
    e.preventDefault();
    const id = recoveryIdentifier.trim() || username.trim() || recoveryEmail.trim();
    if (!id) {
      setRecoveryError('Please enter your username or registered email');
      return;
    }
    setRecoveryLoading(true);
    setRecoveryError('');
    setRecoveryStatus('');
    const res = await apiService.requestPasswordResetCode(id);
    setRecoveryLoading(false);
    if (res.success) {
      setRecoveryIdentifier(id);
      setRecoveryStatus(res.message || 'Recovery code sent to your email.');
      setRecoveryStep('verify');
    } else {
      setRecoveryError(res.message || 'Unable to send recovery code');
    }
  };

  const handleVerifyRecoveryCode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!recoveryCode.trim() || newPassword.length < 6) {
      setRecoveryError('Enter the 6-digit code and a new password (min 6 chars)');
      return;
    }
    setRecoveryLoading(true);
    setRecoveryError('');
    const res = await apiService.verifyPasswordResetCode(
      recoveryIdentifier.trim(),
      recoveryCode.trim(),
      newPassword
    );
    setRecoveryLoading(false);
    if (res.success) {
      setRecoveryStep('done');
      setRecoveryStatus('Password reset successfully! You can now sign in.');
    } else {
      setRecoveryError(res.message || 'Invalid or expired recovery code');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-[#060B11]">
      <div className="w-full max-w-md p-7 sm:p-8 rounded-3xl bg-[#111922] border border-[#1e2836] shadow-2xl relative overflow-hidden">
        {/* Ambient Top Glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-48 h-20 bg-[#00C08B]/10 blur-3xl rounded-full pointer-events-none" />

        {/* Branding with Animated DCS Logo */}
        <div className="text-center mb-7">
          <div className="flex justify-center mb-4">
            <AnimatedDcsLogo className="h-14 sm:h-16" />
          </div>
          <h1 className="text-xl sm:text-2xl font-extrabold text-white tracking-wider">
            MONITORING GATEWAY
          </h1>
          <p className="text-xs text-white/50 mt-1">
            Data Center Specialists • Sign In
          </p>
        </div>

        {error && (
          <div className="mb-4 p-3 rounded-xl bg-[#FF3B30]/15 border border-[#FF3B30]/30 text-xs text-[#FF6961]">
            {error}
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1.5">
              USERNAME
            </label>
            <div className="relative">
              <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40" />
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="Enter admin username"
                className="w-full pl-10 pr-4 py-2.5 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs sm:text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B] transition-colors"
              />
            </div>
          </div>

          <div>
            <label className="text-[11px] font-bold text-white/50 tracking-wider block mb-1.5">
              PASSWORD
            </label>
            <div className="relative">
              <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40" />
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter password"
                className="w-full pl-10 pr-10 py-2.5 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs sm:text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B] transition-colors"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 hover:text-white transition-colors cursor-pointer"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          {/* Keep signed in + Email Recovery */}
          <div className="flex items-center justify-between gap-2">
            <label className="inline-flex items-center gap-2 text-xs text-white/60 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                className="rounded border-[#1e2836] bg-[#0b1119] text-[#00C08B] focus:ring-[#00C08B]"
              />
              <span>Keep me signed in</span>
            </label>
            <button
              type="button"
              onClick={() => {
                setRecoveryIdentifier(username.trim());
                setRecoveryCode('');
                setNewPassword('');
                setRecoveryStep('request');
                setRecoveryError('');
                setRecoveryStatus('');
                setShowForgotModal(true);
              }}
              className="text-xs font-bold text-[#00C08B] hover:text-[#00d89c] transition-colors cursor-pointer"
            >
              Forgot password?
            </button>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 rounded-xl bg-[#00C08B] hover:bg-[#00d89c] disabled:opacity-70 disabled:cursor-not-allowed text-[#060B11] font-extrabold text-sm tracking-wider uppercase transition-all shadow-lg shadow-[#00C08B]/20 cursor-pointer flex items-center justify-center gap-2 mt-2 active:scale-98"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin stroke-[3]" />
                <span>Connecting to API...</span>
              </>
            ) : (
              <>
                <span>Sign In</span>
                <ArrowRight className="w-4 h-4 stroke-[3]" />
              </>
            )}
          </button>

          {/* API Server Indicator */}
          <div className="pt-2 text-center">
            <span className="inline-flex items-center gap-1.5 text-[10px] text-white/40 font-mono">
              <span className="w-1.5 h-1.5 rounded-full bg-[#00C08B] animate-pulse" />
              <span>DCStack API: portal.dcstack.my</span>
            </span>
          </div>
        </form>
      </div>

      {/* Forgot Password / Email Recovery Code Dialog */}
      {showForgotModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm animate-fadeIn">
          <div className="w-full max-w-md p-6 rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl">
            <div className="flex items-center gap-3 pb-3 border-b border-[#1e2836]">
              <div className="p-2 rounded-xl bg-[#00E5FF]/15 text-[#00E5FF]">
                <Mail className="w-5 h-5" />
              </div>
              <h3 className="text-base font-bold text-white">Password Recovery Code</h3>
            </div>

            {recoveryError && (
              <div className="mt-4 p-3 rounded-xl bg-[#FF3B30]/15 border border-[#FF3B30]/30 text-xs text-[#FF6961]">
                {recoveryError}
              </div>
            )}

            {recoveryStatus && (
              <div className="mt-4 p-3 rounded-xl bg-[#00C08B]/15 border border-[#00C08B]/30 text-xs text-[#00C08B] flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0" />
                <span>{recoveryStatus}</span>
              </div>
            )}

            {recoveryStep === 'request' && (
              <form onSubmit={handleSendRecoveryCode} className="mt-4 space-y-4">
                <p className="text-xs text-white/70 leading-relaxed">
                  Enter your portal username or registered recovery email to receive a 6-digit recovery code.
                </p>
                <input
                  type="text"
                  value={recoveryIdentifier}
                  onChange={(e) => setRecoveryIdentifier(e.target.value)}
                  placeholder="Username or recovery email"
                  className="w-full px-3.5 py-2.5 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                />
                <div className="flex items-center justify-end gap-3">
                  <button
                    type="button"
                    onClick={() => setShowForgotModal(false)}
                    className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white transition-colors cursor-pointer"
                  >
                    Close
                  </button>
                  <button
                    type="submit"
                    disabled={recoveryLoading}
                    className="px-4 py-2 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d89c] disabled:opacity-60 text-[#060B11] transition-all cursor-pointer"
                  >
                    {recoveryLoading ? 'Sending...' : 'Send Code'}
                  </button>
                </div>
              </form>
            )}

            {recoveryStep === 'verify' && (
              <form onSubmit={handleVerifyRecoveryCode} className="mt-4 space-y-3">
                <input
                  type="text"
                  value={recoveryCode}
                  onChange={(e) => setRecoveryCode(e.target.value)}
                  placeholder="6-digit recovery code"
                  className="w-full px-3.5 py-2.5 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white font-mono placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                />
                <input
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="New password (min 6 chars)"
                  className="w-full px-3.5 py-2.5 bg-[#0b1119] border border-[#1e2836] rounded-xl text-xs text-white placeholder-white/30 focus:outline-none focus:border-[#00C08B]"
                />
                <div className="flex items-center justify-end gap-3 pt-2">
                  <button
                    type="button"
                    onClick={() => setShowForgotModal(false)}
                    className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white transition-colors cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={recoveryLoading}
                    className="px-4 py-2 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d89c] disabled:opacity-60 text-[#060B11] transition-all cursor-pointer"
                  >
                    {recoveryLoading ? 'Resetting...' : 'Reset Password'}
                  </button>
                </div>
              </form>
            )}

            {recoveryStep === 'done' && (
              <div className="mt-6 flex justify-end">
                <button
                  type="button"
                  onClick={() => setShowForgotModal(false)}
                  className="px-4 py-2 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] transition-all cursor-pointer"
                >
                  Back to Sign In
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
