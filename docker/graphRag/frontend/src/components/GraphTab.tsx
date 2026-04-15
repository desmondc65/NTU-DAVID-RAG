import { useCallback, useEffect, useState } from 'react';
import { buildGraph, fetchCommunities } from '../api';
import type { Community, GraphStatus } from '../types';

interface GraphTabProps {
  status: GraphStatus | null;
  isBlocked: boolean;
  onProcessingChange: (isProcessing: boolean) => void;
  onBuilt: () => void;
}

export default function GraphTab({ status, isBlocked, onProcessingChange, onBuilt }: GraphTabProps) {
  const [communities, setCommunities] = useState<Community[]>([]);
  const [loadingCommunities, setLoadingCommunities] = useState(false);
  const [building, setBuilding] = useState(false);
  const [skipFortran, setSkipFortran] = useState(false);
  const [maxChunks, setMaxChunks] = useState<string>('');
  const [paperFilter, setPaperFilter] = useState<string>('');
  const [buildMsg, setBuildMsg] = useState<{ type: 'success' | 'error' | ''; msg: string }>({ type: '', msg: '' });

  const loadCommunities = useCallback(async () => {
    setLoadingCommunities(true);
    try {
      const data = await fetchCommunities();
      // Sort largest first so the overview is useful at a glance.
      data.sort((a, b) => (b.size ?? 0) - (a.size ?? 0));
      setCommunities(data);
    } catch {
      setCommunities([]);
    } finally {
      setLoadingCommunities(false);
    }
  }, []);

  useEffect(() => {
    loadCommunities();
  }, [loadCommunities, status?.built]);

  const handleBuild = async () => {
    if (building || isBlocked) return;

    const parsedMax = maxChunks.trim() === '' ? undefined : Number(maxChunks);
    if (parsedMax !== undefined && (!Number.isFinite(parsedMax) || parsedMax <= 0)) {
      setBuildMsg({ type: 'error', msg: 'max_chunks must be a positive integer or blank.' });
      return;
    }
    const parsedPapers = paperFilter
      .split(/\n+/)
      .map((s) => s.trim())
      .filter(Boolean);

    setBuilding(true);
    onProcessingChange(true);
    setBuildMsg({ type: '', msg: 'Building knowledge graph… this can take several minutes per paper.' });

    try {
      const res = await buildGraph({
        skip_fortran: skipFortran,
        max_chunks: parsedMax ?? null,
        paper_filter: parsedPapers.length > 0 ? parsedPapers : null,
      });
      setBuildMsg({
        type: 'success',
        msg: `Built: ${res.stats.n_nodes} nodes, ${res.stats.n_edges} edges, ${res.stats.n_communities} communities across ${res.stats.n_chunks} chunks.`,
      });
      onBuilt();
      await loadCommunities();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Build failed';
      setBuildMsg({ type: 'error', msg });
    } finally {
      setBuilding(false);
      onProcessingChange(false);
    }
  };

  const formatDate = (iso?: string) => {
    if (!iso) return '—';
    try {
      return new Date(iso).toLocaleString();
    } catch {
      return iso;
    }
  };

  return (
    <div>
      {/* ── Graph status ──────────────────────────────────────────────── */}
      <div className="card">
        <h2 className="card-title">Knowledge Graph</h2>

        {status?.built ? (
          <>
            <p className="status-message success" style={{ marginTop: 0 }}>
              ✓ Graph is built. Last built: {formatDate(status.built_at)}
            </p>
            <div className="stats-row">
              <div className="stat-pill">
                <span className="stat-pill-label">Chunks</span>
                <span className="stat-pill-value">{status.n_chunks ?? '—'}</span>
              </div>
              <div className="stat-pill">
                <span className="stat-pill-label">Entities</span>
                <span className="stat-pill-value">{status.n_nodes ?? '—'}</span>
              </div>
              <div className="stat-pill">
                <span className="stat-pill-label">Relationships</span>
                <span className="stat-pill-value">{status.n_edges ?? '—'}</span>
              </div>
              <div className="stat-pill">
                <span className="stat-pill-label">Communities</span>
                <span className="stat-pill-value">{status.n_communities ?? '—'}</span>
              </div>
            </div>
          </>
        ) : (
          <p className="status-message" style={{ marginTop: 0 }}>
            No graph yet — upload papers and trigger a build below.
          </p>
        )}
      </div>

      {/* ── Build controls ────────────────────────────────────────────── */}
      <div className="card mt-3">
        <h2 className="card-title">
          {status?.built ? 'Rebuild Graph' : 'Build Graph'}
        </h2>

        <p className="status-message" style={{ marginTop: 0, marginBottom: '0.75rem' }}>
          Each chunk is passed through the LLM for entity and relationship extraction,
          so builds scale roughly linearly with corpus size.
        </p>

        <div className="flex gap-1" style={{ flexWrap: 'wrap', alignItems: 'center' }}>
          <label className="flex items-center gap-1" style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
            <input
              type="checkbox"
              checked={skipFortran}
              onChange={(e) => setSkipFortran(e.target.checked)}
              disabled={building || isBlocked}
            />
            Skip Fortran chunks
          </label>

          <label className="flex items-center gap-1" style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
            Max chunks (optional)
            <input
              className="query-input"
              type="number"
              min={1}
              placeholder="e.g. 200"
              value={maxChunks}
              onChange={(e) => setMaxChunks(e.target.value)}
              disabled={building || isBlocked}
              style={{ width: '120px', padding: '0.4rem 0.7rem', fontSize: '0.85rem' }}
            />
          </label>
        </div>

        <div style={{ marginTop: '0.75rem' }}>
          <label
            className="status-message"
            style={{ marginBottom: '0.3rem', display: 'block', color: 'var(--text-secondary)' }}
          >
            Restrict to specific paper titles (optional, one per line):
          </label>
          <textarea
            className="query-input"
            rows={3}
            placeholder="Leave blank to include every paper in the registry"
            value={paperFilter}
            onChange={(e) => setPaperFilter(e.target.value)}
            disabled={building || isBlocked}
            style={{ width: '100%', resize: 'vertical', padding: '0.6rem 0.9rem' }}
          />
        </div>

        <button
          className="btn btn-build upload-primary-action"
          disabled={building || isBlocked}
          onClick={handleBuild}
        >
          {building
            ? <><span className="spinner" /> Building graph…</>
            : status?.built ? '🔁 Rebuild Graph' : '🏗 Build Graph'}
        </button>

        {building && (
          <div className="progress-bar-container">
            <div className="progress-bar" />
          </div>
        )}

        {buildMsg.msg && (
          <p className={`status-message ${buildMsg.type}`}>
            {buildMsg.type === 'success' && '✓ '}
            {buildMsg.type === 'error' && '✗ '}
            {buildMsg.msg}
          </p>
        )}

        {isBlocked && !building && (
          <p className="status-message">
            ⏳ Another long-running task is active — wait for it to finish.
          </p>
        )}
      </div>

      {/* ── Communities browser ───────────────────────────────────────── */}
      <div className="card mt-3">
        <div className="flex items-center justify-between">
          <h2 className="card-title" style={{ marginBottom: 0 }}>Communities</h2>
          <span style={{ color: 'var(--text-muted)', fontSize: '0.82rem' }}>
            {communities.length} cluster{communities.length !== 1 ? 's' : ''}
          </span>
        </div>

        {loadingCommunities ? (
          <div className="empty-state">
            <span className="spinner" />
          </div>
        ) : communities.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon">🕸</div>
            <p className="empty-state-text">
              No communities yet — build the graph first.
            </p>
          </div>
        ) : (
          <div style={{ marginTop: '0.75rem' }}>
            {communities.map((c) => (
              <div className="community-card" key={c.community_id}>
                <div className="community-header">
                  <span className="community-title">
                    [Cm-{c.community_id}] {c.title}
                  </span>
                  <span className="community-meta">
                    {c.size} entit{c.size === 1 ? 'y' : 'ies'} · {c.paper_titles?.length ?? 0} paper{(c.paper_titles?.length ?? 0) === 1 ? '' : 's'}
                  </span>
                </div>
                {c.theme && <div className="community-theme">Theme: {c.theme}</div>}
                {c.summary && <div className="community-summary">{c.summary}</div>}
                {c.key_entities && c.key_entities.length > 0 && (
                  <div className="community-entities">
                    {c.key_entities.map((e) => (
                      <span className="entity-chip" key={e}>{e}</span>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
