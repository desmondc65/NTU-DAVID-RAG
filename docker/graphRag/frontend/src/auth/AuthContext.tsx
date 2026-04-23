import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {
  authLogin,
  authLogout,
  authMe,
  authRegister,
  onUnauthorized,
  type AuthUser,
} from '../api';

type AuthState = {
  user: AuthUser | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, displayName?: string) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
};

const AuthCtx = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const mounted = useRef(true);

  useEffect(() => () => { mounted.current = false; }, []);

  const refresh = useCallback(async () => {
    const u = await authMe();
    if (mounted.current) setUser(u);
  }, []);

  useEffect(() => {
    (async () => {
      try {
        await refresh();
      } finally {
        if (mounted.current) setLoading(false);
      }
    })();
  }, [refresh]);

  // 401 from any API call → treat as logged out immediately.
  useEffect(() => onUnauthorized(() => {
    if (mounted.current) setUser(null);
  }), []);

  const login = useCallback(async (email: string, password: string) => {
    const u = await authLogin(email, password);
    if (mounted.current) setUser(u);
  }, []);

  const signup = useCallback(async (email: string, password: string, displayName?: string) => {
    const u = await authRegister(email, password, displayName);
    if (mounted.current) setUser(u);
  }, []);

  const logout = useCallback(async () => {
    try {
      await authLogout();
    } finally {
      if (mounted.current) setUser(null);
    }
  }, []);

  const value = useMemo<AuthState>(() => ({
    user,
    loading,
    login,
    signup,
    logout,
    refresh,
  }), [user, loading, login, signup, logout, refresh]);

  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthCtx);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}
