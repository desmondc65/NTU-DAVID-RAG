/** API helper functions. */
import type { ChatTurn, Paper, QueryResponse, UploadResponse } from './types';

const API_BASE = '/api';

export async function fetchPapers(): Promise<Paper[]> {
  const res = await fetch(`${API_BASE}/papers`);
  if (!res.ok) throw new Error(`Failed to load papers: ${res.statusText}`);
  return res.json();
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

  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Upload failed');
  return data;
}

export async function deletePaper(title: string): Promise<void> {
  const res = await fetch(`${API_BASE}/papers/${encodeURIComponent(title)}`, {
    method: 'DELETE',
  });
  if (!res.ok) {
    const data = await res.json();
    throw new Error(data.error || 'Delete failed');
  }
}

export async function queryRAG(
  query: string,
  topK: number = 10,
  history: ChatTurn[] = [],
): Promise<QueryResponse> {
  const res = await fetch(`${API_BASE}/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, top_k: topK, history }),
  });

  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Query failed');
  return data;
}
