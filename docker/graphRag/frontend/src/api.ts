/** API helper functions for the GraphRAG backend. */
import type {
  BuildRequest,
  BuildResponse,
  Community,
  GraphStatus,
  Paper,
  QueryRequest,
  QueryResponse,
  UploadResponse,
} from './types';

const API_BASE = '/api';

async function handle<T>(res: Response): Promise<T> {
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = (data as { error?: string }).error || res.statusText;
    throw new Error(msg);
  }
  return data as T;
}

/* ── Status ─────────────────────────────────────────────────────────── */
export async function fetchStatus(): Promise<GraphStatus> {
  const res = await fetch(`${API_BASE}/status`);
  return handle<GraphStatus>(res);
}

/* ── Papers ─────────────────────────────────────────────────────────── */
export async function fetchPapers(): Promise<Paper[]> {
  const res = await fetch(`${API_BASE}/papers`);
  return handle<Paper[]>(res);
}

export async function uploadPaper(
  pdfFile: File,
  fortranFile: File,
): Promise<UploadResponse> {
  const form = new FormData();
  form.append('pdf', pdfFile);
  form.append('fortran', fortranFile);
  const res = await fetch(`${API_BASE}/papers`, {
    method: 'POST',
    body: form,
  });
  return handle<UploadResponse>(res);
}

export async function deletePaper(title: string): Promise<void> {
  const res = await fetch(`${API_BASE}/papers/${encodeURIComponent(title)}`, {
    method: 'DELETE',
  });
  await handle<unknown>(res);
}

/* ── Graph build / communities ─────────────────────────────────────── */
export async function buildGraph(body: BuildRequest = {}): Promise<BuildResponse> {
  const res = await fetch(`${API_BASE}/build`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return handle<BuildResponse>(res);
}

export async function fetchCommunities(): Promise<Community[]> {
  const res = await fetch(`${API_BASE}/communities`);
  return handle<Community[]>(res);
}

/* ── Query ─────────────────────────────────────────────────────────── */
export async function runQuery(req: QueryRequest): Promise<QueryResponse> {
  const res = await fetch(`${API_BASE}/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(req),
  });
  return handle<QueryResponse>(res);
}
