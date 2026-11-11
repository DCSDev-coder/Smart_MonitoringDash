import React, { useState } from 'react';
import { Lock, User, Eye, EyeOff, Mail, ArrowRight, CheckCircle2 } from 'lucide-react';

interface LoginModalProps {
  onLogin: (username: string) => void;
  recoveryEmail: string;
}

export const LoginModal: React.FC<LoginModalProps> = ({ onLogin, recoveryEmail }) => {
  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('admin123');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [showForgotModal, setShowForgotModal] = useState(false);
  const [forgotSent, setForgotSent] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      setError('Please enter both username and password');
      return;
    }
    // Simple authentication
    onLogin(username.trim());
  };

  const handleSendRecovery = () => {
    setForgotSent(true);
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-[#060B11]">
      <div className="w-full max-w-md p-7 sm:p-8 rounded-3xl bg-[#111922] border border-[#1e2836] shadow-2xl relative overflow-hidden">
        {/* Ambient Top Glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-48 h-20 bg-[#00C08B]/10 blur-3xl rounded-full pointer-events-none" />

        {/* Branding with DCS Logo */}
        <div className="text-center mb-7">
          <img
            src="/dcs_logo.png"
            alt="DCS Data Center Specialists"
            className="h-14 sm:h-16 mx-auto object-contain mb-4 drop-shadow-md"
          />
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

          {/* Email Recovery Shortcut */}
          <div className="flex justify-end">
            <button
              type="button"
              onClick={() => {
                setForgotSent(false);
                setShowForgotModal(true);
              }}
              className="text-xs font-bold text-[#00C08B] hover:text-[#00d89c] transition-colors cursor-pointer"
            >
              Forgot password? (Email Recovery)
            </button>
          </div>

          <button
            type="submit"
            className="w-full py-3 rounded-xl bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] font-extrabold text-sm tracking-wider uppercase transition-all shadow-lg shadow-[#00C08B]/20 cursor-pointer flex items-center justify-center gap-2 mt-2 active:scale-98"
          >
            <span>Sign In</span>
            <ArrowRight className="w-4 h-4 stroke-[3]" />
          </button>
        </form>
      </div>

      {/* Forgot Password / Email Recovery Dialog */}
      {showForgotModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm animate-fadeIn">
          <div className="w-full max-w-md p-6 rounded-2xl bg-[#111922] border border-[#1e2836] shadow-2xl">
            <div className="flex items-center gap-3 pb-3 border-b border-[#1e2836]">
              <div className="p-2 rounded-xl bg-[#00E5FF]/15 text-[#00E5FF]">
                <Mail className="w-5 h-5" />
              </div>
              <h3 className="text-base font-bold text-white">Admin Password Recovery</h3>
            </div>

            <p className="text-xs text-white/70 mt-4 leading-relaxed">
              If you forgot your password, we can send a one-time password reset link to your registered recovery email:
            </p>
            <div className="mt-3 p-3 rounded-xl bg-[#0b1119] border border-[#1e2836] font-mono text-xs text-[#00E5FF]">
              {recoveryEmail}
            </div>

            {forgotSent ? (
              <div className="mt-4 p-3 rounded-xl bg-[#00C08B]/15 border border-[#00C08B]/30 text-xs text-[#00C08B] flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0" />
                <span>Recovery email sent! Check your inbox to reset your password.</span>
              </div>
            ) : null}

            <div className="mt-6 flex items-center justify-end gap-3">
              <button
                onClick={() => setShowForgotModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-white/60 hover:text-white transition-colors cursor-pointer"
              >
                Close
              </button>
              {!forgotSent && (
                <button
                  onClick={handleSendRecovery}
                  className="px-4 py-2 rounded-xl text-xs font-bold bg-[#00C08B] hover:bg-[#00d89c] text-[#060B11] transition-all cursor-pointer shadow-lg shadow-[#00C08B]/20"
                >
                  Send Recovery Email
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
