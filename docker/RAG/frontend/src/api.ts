/** API helper functions. */
import type { Paper, QueryResponse, UploadResponse } from './types';

// Vite's BASE_URL reflects the build-time `base` setting (defaults to '/').
// When the app is hosted under a prefix by the unified proxy (e.g. '/rag/'),
// API calls must use that prefix so nginx routes them to this backend.
const API_BASE = `${(import.meta.env.BASE_URL || '/').replace(/\/$/, '')}/api`;

// Auth endpoints are always routed by nginx at the origin root (not under the
// app prefix), so login/logout work identically from /rag/ and /graph/.
const AUTH_BASE = '/api/auth';

export type AuthUser = {
  id: string;
  email: string;
  display_name: string | null;
};

/** Raised when the server returns 401 on an authenticated request. */
export class UnauthorizedError extends Error {
  constructor() {
    super('unauthorized');
    this.name = 'UnauthorizedError';
  }
}

function readCsrfCookie(): string | null {
  const match = document.cookie.match(/(?:^|;\s*)csrf_token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : null;
}

type AuthListener = () => void;
const unauthorizedListeners = new Set<AuthListener>();

export function onUnauthorized(fn: AuthListener): () => void {
  unauthorizedListeners.add(fn);
  return () => unauthorizedListeners.delete(fn);
}

/**
 * Central fetch wrapper: credentialed, CSRF-aware, and 401-reactive.
 * All non-auth API calls should route through here so session handling
 * stays consistent.
 */
async function apiFetch<T>(
  input: string,
  init: RequestInit = {},
): Promise<T> {
  const method = (init.method || 'GET').toUpperCase();
  const headers = new Headers(init.headers);

  if (method !== 'GET' && method !== 'HEAD') {
    const csrf = readCsrfCookie();
    if (csrf) headers.set('X-CSRF-Token', csrf);
  }

  const res = await fetch(input, {
    ...init,
    credentials: 'include',
    headers,
  });

  if (res.status === 401) {
    unauthorizedListeners.forEach((fn) => {
      try { fn(); } catch { /* listener errors must not block */ }
    });
    throw new UnauthorizedError();
  }

  const contentType = res.headers.get('content-type') || '';
  const data = contentType.includes('application/json')
    ? await res.json().catch(() => ({}))
    : undefined;

  if (!res.ok) {
    const msg = (data && (data as { error?: string }).error) || res.statusText;
    throw new Error(msg);
  }
  return (data ?? (undefined as unknown)) as T;
}

/* ── Auth ──────────────────────────────────────────────────────────── */

export async function authMe(): Promise<AuthUser | null> {
  try {
    const data = await apiFetch<{ user: AuthUser }>(`${AUTH_BASE}/me`);
    return data.user;
  } catch (err) {
    if (err instanceof UnauthorizedError) return null;
    throw err;
  }
}

export async function authLogin(email: string, password: string): Promise<AuthUser> {
  const data = await apiFetch<{ user: AuthUser }>(`${AUTH_BASE}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  return data.user;
}

export async function authRegister(
  email: string,
  password: string,
  displayName?: string,
): Promise<AuthUser> {
  const data = await apiFetch<{ user: AuthUser }>(`${AUTH_BASE}/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      display_name: displayName || undefined,
    }),
  });
  return data.user;
}

export async function authLogout(): Promise<void> {
  await apiFetch<void>(`${AUTH_BASE}/logout`, { method: 'POST' });
}

export async function authChangePassword(
  oldPassword: string,
  newPassword: string,
): Promise<{ other_sessions_revoked: number }> {
  return apiFetch<{ other_sessions_revoked: number }>(
    `${AUTH_BASE}/password/change`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ old_password: oldPassword, new_password: newPassword }),
    },
  );
}

export type AuthSessionRow = {
  id: string;
  created_at: string | null;
  last_seen_at: string | null;
  expires_at: string | null;
  ip: string | null;
  user_agent: string | null;
  current: boolean;
};

export async function authListSessions(): Promise<AuthSessionRow[]> {
  return apiFetch<AuthSessionRow[]>(`${AUTH_BASE}/sessions`);
}

export async function authRevokeSession(id: string): Promise<void> {
  await apiFetch<unknown>(`${AUTH_BASE}/sessions/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

export async function authRevokeOtherSessions(): Promise<{ revoked: number }> {
  return apiFetch<{ revoked: number }>(`${AUTH_BASE}/sessions/revoke-others`, {
    method: 'POST',
  });
}

/* ── Papers ────────────────────────────────────────────────────────── */

export async function fetchPapers(): Promise<Paper[]> {
  return apiFetch<Paper[]>(`${API_BASE}/papers`);
}

export async function uploadPaper(
  pdfFile: File,
  fortranFile?: File | null,
): Promise<UploadResponse> {
  const form = new FormData();
  form.append('pdf', pdfFile);
  if (fortranFile) {
    form.append('fortran', fortranFile);
  }
  return apiFetch<UploadResponse>(`${API_BASE}/papers`, {
    method: 'POST',
    body: form,
  });
}

export async function deletePaper(title: string): Promise<void> {
  await apiFetch<unknown>(`${API_BASE}/papers/${encodeURIComponent(title)}`, {
    method: 'DELETE',
  });
}

/* ── Conversations & messages ─────────────────────────────────────── */

export type ConversationSummary = {
  id: string;
  title: string;
  created_at: string;
  updated_at: string;
  last_message_at: string | null;
  message_count: number;
};

export type ServerMessage = {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  sources: unknown;
  metadata: Record<string, unknown> | null;
  parent_message_id: string | null;
  created_at: string | null;
};

export async function fetchConversations(): Promise<ConversationSummary[]> {
  return apiFetch<ConversationSummary[]>(`${API_BASE}/conversations`);
}

export async function createConversation(title?: string): Promise<ConversationSummary> {
  return apiFetch<ConversationSummary>(`${API_BASE}/conversations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(title ? { title } : {}),
  });
}

export async function renameConversation(id: string, title: string): Promise<ConversationSummary> {
  return apiFetch<ConversationSummary>(`${API_BASE}/conversations/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title }),
  });
}

export async function deleteConversation(id: string): Promise<void> {
  await apiFetch<unknown>(`${API_BASE}/conversations/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

export async function fetchMessages(conversationId: string): Promise<ServerMessage[]> {
  return apiFetch<ServerMessage[]>(
    `${API_BASE}/conversations/${encodeURIComponent(conversationId)}/messages`,
  );
}

export async function deleteMessage(conversationId: string, messageId: string): Promise<void> {
  await apiFetch<unknown>(
    `${API_BASE}/conversations/${encodeURIComponent(conversationId)}/messages/${encodeURIComponent(messageId)}`,
    { method: 'DELETE' },
  );
}

/* ── Query ─────────────────────────────────────────────────────────── */

export type QueryRequestBody = {
  query: string;
  top_k?: number;
  conversation_id?: string | null;
};

export async function queryRAG(
  body: QueryRequestBody,
  signal?: AbortSignal,
): Promise<QueryResponse> {
  return apiFetch<QueryResponse>(`${API_BASE}/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal,
  });
}
