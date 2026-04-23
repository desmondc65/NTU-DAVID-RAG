import { useCallback, useEffect, useState, type FormEvent } from 'react';
import {
  authChangePassword,
  authListSessions,
  authRevokeOtherSessions,
  authRevokeSession,
  type AuthSessionRow,
} from '../api';
import { useAuth } from './AuthContext';

type Props = {
  open: boolean;
  onClose: () => void;
};

function relTime(iso: string | null): string {
  if (!iso) return '—';
  const t = new Date(iso).getTime();
  if (!Number.isFinite(t)) return '—';
  const diff = Date.now() - t;
  const s = Math.floor(diff / 1000);
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d}d ago`;
  return new Date(iso).toLocaleDateString();
}

function shortUA(ua: string | null): string {
  if (!ua) return 'Unknown device';
  const match = ua.match(/(Chrome|Safari|Firefox|Edge|OPR|Edg|Postman|curl)[^\s;)]*/i);
  const os = ua.match(/(Mac OS X|Windows NT [\d.]+|Linux|Android|iOS|iPhone|iPad)/);
  const browser = match ? match[0].replace('Edg', 'Edge').replace('OPR', 'Opera') : 'Browser';
  return os ? `${browser} · ${os[0]}` : browser;
}

export default function AccountDialog({ open, onClose }: Props) {
  const { user, refresh } = useAuth();

  // ── Change password state ───────────────────────────────────────
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [pwSubmitting, setPwSubmitting] = useState(false);
  const [pwError, setPwError] = useState<string | null>(null);
  const [pwSuccess, setPwSuccess] = useState<string | null>(null);

  // ── Sessions state ──────────────────────────────────────────────
  const [sessions, setSessions] = useState<AuthSessionRow[]>([]);
  const [sessionsLoading, setSessionsLoading] = useState(false);
  const [sessionsError, setSessionsError] = useState<string | null>(null);

  const loadSessions = useCallback(async () => {
    setSessionsLoading(true);
    setSessionsError(null);
    try {
      const rows = await authListSessions();
      setSessions(rows);
    } catch (err) {
      setSessionsError(err instanceof Error ? err.message : 'Failed to load sessions');
    } finally {
      setSessionsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!open) return;
    setPwError(null);
    setPwSuccess(null);
    setOldPassword('');
    setNewPassword('');
    setConfirmPassword('');
    void loadSessions();
  }, [open, loadSessions]);

  if (!open) return null;

  const submitPasswordChange = async (e: FormEvent) => {
    e.preventDefault();
    setPwError(null);
    setPwSuccess(null);
    if (newPassword !== confirmPassword) {
      setPwError('New passwords do not match.');
      return;
    }
    setPwSubmitting(true);
    try {
      const res = await authChangePassword(oldPassword, newPassword);
      setPwSuccess(
        res.other_sessions_revoked > 0
          ? `Password updated. ${res.other_sessions_revoked} other session(s) were signed out.`
          : 'Password updated.',
      );
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
      await loadSessions();
    } catch (err) {
      setPwError(err instanceof Error ? err.message : 'Could not change password');
    } finally {
      setPwSubmitting(false);
    }
  };

  const handleRevoke = async (id: string, isCurrent: boolean) => {
    const prompt = isCurrent
      ? 'This is your current session. Revoking it will sign you out. Continue?'
      : 'Sign this session out of the platform?';
    if (!window.confirm(prompt)) return;
    try {
      await authRevokeSession(id);
      if (isCurrent) {
        await refresh();
        onClose();
        return;
      }
      await loadSessions();
    } catch (err) {
      setSessionsError(err instanceof Error ? err.message : 'Revoke failed');
    }
  };

  const handleRevokeOthers = async () => {
    if (!window.confirm('Sign out every session except this one?')) return;
    try {
      await authRevokeOtherSessions();
      await loadSessions();
    } catch (err) {
      setSessionsError(err instanceof Error ? err.message : 'Revoke failed');
    }
  };

  return (
    <div className="account-dialog-backdrop" onMouseDown={onClose}>
      <div
        className="account-dialog"
        role="dialog"
        aria-modal="true"
        aria-label="Account settings"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <header className="account-dialog-header">
          <div>
            <div className="account-dialog-title">Account</div>
            <div className="account-dialog-sub">{user?.email}</div>
          </div>
          <button type="button" className="account-dialog-close" onClick={onClose} aria-label="Close">
            ✕
          </button>
        </header>

        <section className="account-section">
          <h3 className="account-section-title">Change password</h3>
          <form onSubmit={submitPasswordChange} className="account-form">
            <label className="auth-field">
              <span>Current password</span>
              <input
                type="password"
                autoComplete="current-password"
                value={oldPassword}
                onChange={(e) => setOldPassword(e.target.value)}
                required
                disabled={pwSubmitting}
              />
            </label>
            <label className="auth-field">
              <span>New password</span>
              <input
                type="password"
                autoComplete="new-password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                minLength={12}
                disabled={pwSubmitting}
              />
            </label>
            <label className="auth-field">
              <span>Confirm new password</span>
              <input
                type="password"
                autoComplete="new-password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                minLength={12}
                disabled={pwSubmitting}
              />
            </label>
            <p className="auth-hint">
              At least 12 characters, mixing two of: lowercase, uppercase, digits, symbols.
              All other active sessions are signed out.
            </p>
            {pwError && <p className="auth-error" role="alert">{pwError}</p>}
            {pwSuccess && <p className="auth-success">{pwSuccess}</p>}
            <button type="submit" className="auth-submit" disabled={pwSubmitting}>
              {pwSubmitting ? 'Updating…' : 'Update password'}
            </button>
          </form>
        </section>

        <section className="account-section">
          <div className="account-section-row">
            <h3 className="account-section-title">Active sessions</h3>
            <button
              type="button"
              className="btn btn-small"
              onClick={() => void handleRevokeOthers()}
              disabled={sessionsLoading || sessions.filter((s) => !s.current).length === 0}
              title="Sign out every other session"
            >
              Sign out elsewhere
            </button>
          </div>
          {sessionsError && <p className="auth-error" role="alert">{sessionsError}</p>}
          {sessionsLoading && <p className="conv-empty">Loading…</p>}
          {!sessionsLoading && sessions.length === 0 && (
            <p className="conv-empty">No active sessions.</p>
          )}
          <ul className="session-list">
            {sessions.map((s) => (
              <li key={s.id} className={`session-item ${s.current ? 'is-current' : ''}`}>
                <div className="session-main">
                  <div className="session-device">
                    {shortUA(s.user_agent)}
                    {s.current && <span className="session-badge">This device</span>}
                  </div>
                  <div className="session-meta">
                    {s.ip ? `${s.ip} · ` : ''}Last seen {relTime(s.last_seen_at)}
                  </div>
                </div>
                <button
                  type="button"
                  className="conv-icon-btn danger"
                  title={s.current ? 'Sign out this device' : 'Sign this session out'}
                  onClick={() => void handleRevoke(s.id, s.current)}
                >
                  Sign out
                </button>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  );
}
