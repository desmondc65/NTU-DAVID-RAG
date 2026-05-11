import { useState, useEffect, useCallback, type DragEvent } from 'react';
import { fetchPapers, uploadPaper, deletePaper } from '../api';
import type { Paper } from '../types';

type UploadState = 'queued' | 'processing' | 'success' | 'error';

interface UploadQueueItem {
  id: string;
  pdfName: string;
  fortranName: string;  // "—" when no Fortran was attached
  status: UploadState;
  message: string;
}

interface UploadPair {
  id: string;
  pdf: File;
  fortran: File | null;
}

interface DraftPair {
  id: string;
  pdf: File | null;
  fortran: File | null;
}

interface ManagePapersProps {
  onProcessingChange: (isProcessing: boolean) => void;
}

function makePairId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export default function ManagePapers({ onProcessingChange }: ManagePapersProps) {
  const [papers, setPapers] = useState<Paper[]>([]);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
  const [status, setStatus] = useState<{ type: 'success' | 'error' | ''; msg: string }>({ type: '', msg: '' });
  const [draftPairs, setDraftPairs] = useState<DraftPair[]>([
    { id: makePairId(), pdf: null, fortran: null },
  ]);
  const [uploadQueue, setUploadQueue] = useState<UploadQueueItem[]>([]);
  const [dragTarget, setDragTarget] = useState<{ pairId: string; kind: 'pdf' | 'fortran' } | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);

  const loadPapers = useCallback(async () => {
    try {
      const data = await fetchPapers();
      setPapers(data);
    } catch {
      // Papers might not exist yet
      setPapers([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadPapers();
  }, [loadPapers]);

  useEffect(() => {
    onProcessingChange(processing);
  }, [processing, onProcessingChange]);

  useEffect(() => {
    return () => onProcessingChange(false);
  }, [onProcessingChange]);

  const updatePairFile = (pairId: string, kind: 'pdf' | 'fortran', file: File | null) => {
    setDraftPairs((prev) => prev.map((pair) => {
      if (pair.id !== pairId) return pair;
      return { ...pair, [kind]: file };
    }));
  };

  const addEmptyPair = () => {
    if (processing) return;
    setDraftPairs((prev) => [...prev, { id: makePairId(), pdf: null, fortran: null }]);
  };

  const removePair = (pairId: string) => {
    if (processing) return;
    setDraftPairs((prev) => {
      const next = prev.filter((pair) => pair.id !== pairId);
      return next.length > 0 ? next : [{ id: makePairId(), pdf: null, fortran: null }];
    });
  };

  const handlePairDrop = (pairId: string, kind: 'pdf' | 'fortran', e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setDragTarget(null);
    const files = Array.from(e.dataTransfer.files);
    if (files.length === 0) return;

    const picked = kind === 'pdf'
      ? files.find((file) => file.name.toLowerCase().endsWith('.pdf'))
      : files.find((file) => !file.name.toLowerCase().endsWith('.pdf'));

    if (!picked) return;
    updatePairFile(pairId, kind, picked);
  };

  const buildUploadPairs = (): { pairs: UploadPair[]; missing: string[] } => {
    const pairs: UploadPair[] = [];
    const missing: string[] = [];

    draftPairs.forEach((pair, idx) => {
      // A PDF is required; Fortran is optional companion code.
      if (pair.pdf) {
        pairs.push({
          id: pair.id,
          pdf: pair.pdf,
          fortran: pair.fortran,
        });
        return;
      }

      if (pair.fortran) {
        // Fortran selected without a PDF — can't ingest, flag it.
        missing.push(`Pair ${idx + 1}`);
      }
    });

    return { pairs, missing };
  };

  const handleUpload = async () => {
    if (processing) return;
    const hasAnySelection = draftPairs.some((pair) => pair.pdf || pair.fortran);
    if (!hasAnySelection) {
      setStatus({ type: 'error', msg: 'Add at least one row with a PDF (Fortran optional).' });
      return;
    }

    const { pairs, missing } = buildUploadPairs();
    if (pairs.length === 0) {
      setStatus({ type: 'error', msg: 'Each row needs a PDF — Fortran alone cannot be ingested.' });
      return;
    }

    const initialQueue: UploadQueueItem[] = [
      ...pairs.map((p) => ({
        id: p.id,
        pdfName: p.pdf.name,
        fortranName: p.fortran ? p.fortran.name : '—',
        status: 'queued' as UploadState,
        message: 'Queued',
      })),
      ...missing.map((label) => ({
        id: `missing__${label}`,
        pdfName: label,
        fortranName: 'Missing PDF',
        status: 'error' as UploadState,
        message: 'Fortran selected without a PDF — add a PDF or remove the row',
      })),
    ];

    setUploadQueue(initialQueue);
    setProcessing(true);

    let successCount = 0;
    for (let i = 0; i < pairs.length; i += 1) {
      const pair = pairs[i];
      const fortranLabel = pair.fortran ? ` + ${pair.fortran.name}` : '';
      setStatus({
        type: '',
        msg: `Processing ${i + 1}/${pairs.length}: ${pair.pdf.name}${fortranLabel}`,
      });
      setUploadQueue((prev) => prev.map((item) => (
        item.id === pair.id
          ? { ...item, status: 'processing', message: 'Processing…' }
          : item
      )));

      try {
        const res = await uploadPaper(pair.pdf, pair.fortran);
        successCount += 1;
        setUploadQueue((prev) => prev.map((item) => (
          item.id === pair.id
            ? { ...item, status: 'success', message: res.message || 'Done' }
            : item
        )));
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Upload failed';
        setUploadQueue((prev) => prev.map((item) => (
          item.id === pair.id
            ? { ...item, status: 'error', message: msg }
            : item
        )));
      }
    }

    await loadPapers();
    setProcessing(false);

    if (missing.length === 0 && successCount === pairs.length) {
      setStatus({ type: 'success', msg: `Completed ${successCount}/${pairs.length} papers.` });
    } else {
      const totalErrors = pairs.length - successCount + missing.length;
      setStatus({
        type: totalErrors > 0 ? 'error' : 'success',
        msg: `Done: ${successCount} success, ${totalErrors} failed/unmatched.`,
      });
    }
  };

  const uploadablePairCount = draftPairs.filter((pair) => pair.pdf).length;
  const hasOrphanFortran = draftPairs.some((pair) => pair.fortran && !pair.pdf);

  const handleDelete = async (title: string) => {
    if (!window.confirm(`Delete "${title}" and all its vectors?`)) return;
    setDeleting(title);
    try {
      await deletePaper(title);
      setStatus({ type: 'success', msg: `Deleted "${title}"` });
      await loadPapers();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Delete failed';
      setStatus({ type: 'error', msg });
    } finally {
      setDeleting(null);
    }
  };

  const formatDate = (iso: string) => {
    try {
      return new Date(iso).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
    } catch {
      return iso;
    }
  };

  return (
    <div>
      {/* ── Upload Section ─────────────────────────────────────────────── */}
      <div className="card">
        <h2 className="card-title">Upload Paper &amp; Code</h2>

        <p className="status-message" style={{ marginTop: 0, marginBottom: '0.75rem' }}>
          One row per paper. PDF is required; Fortran source is optional companion code.
        </p>

        <div className="pair-list">
          {draftPairs.map((pair, idx) => (
            <div className="pair-row" key={pair.id}>
              <div className="pair-row-header">
                <h3 className="pair-row-title">Pair {idx + 1}</h3>
                <button
                  className="btn btn-sm"
                  disabled={processing || draftPairs.length === 1}
                  onClick={() => removePair(pair.id)}
                >
                  Remove Pair
                </button>
              </div>

              <div className="upload-grid">
                <div
                  className={`upload-zone ${dragTarget?.pairId === pair.id && dragTarget?.kind === 'pdf' ? 'drag-over' : ''}`}
                  onDragOver={(e) => { e.preventDefault(); setDragTarget({ pairId: pair.id, kind: 'pdf' }); }}
                  onDragLeave={() => setDragTarget(null)}
                  onDrop={(e) => handlePairDrop(pair.id, 'pdf', e)}
                  onClick={() => {
                    if (processing) return;
                    const input = document.getElementById(`pdf-input-${pair.id}`) as HTMLInputElement | null;
                    input?.click();
                  }}
                >
                  <div className="upload-zone-icon">📄</div>
                  <p className="upload-zone-text">
                    <strong>Paper PDF</strong><br />
                    Drop or click to select
                  </p>
                </div>

                <div
                  className={`upload-zone ${dragTarget?.pairId === pair.id && dragTarget?.kind === 'fortran' ? 'drag-over' : ''}`}
                  onDragOver={(e) => { e.preventDefault(); setDragTarget({ pairId: pair.id, kind: 'fortran' }); }}
                  onDragLeave={() => setDragTarget(null)}
                  onDrop={(e) => handlePairDrop(pair.id, 'fortran', e)}
                  onClick={() => {
                    if (processing) return;
                    const input = document.getElementById(`fortran-input-${pair.id}`) as HTMLInputElement | null;
                    input?.click();
                  }}
                >
                  <div className="upload-zone-icon">💻</div>
                  <p className="upload-zone-text">
                    <strong>Fortran Source</strong> <span style={{ opacity: 0.7 }}>(optional)</span><br />
                    Drop or click to select
                  </p>
                </div>
              </div>

              <input
                id={`pdf-input-${pair.id}`}
                type="file"
                accept=".pdf"
                style={{ display: 'none' }}
                onChange={(e) => updatePairFile(pair.id, 'pdf', e.target.files?.[0] || null)}
              />
              <input
                id={`fortran-input-${pair.id}`}
                type="file"
                style={{ display: 'none' }}
                onChange={(e) => updatePairFile(pair.id, 'fortran', e.target.files?.[0] || null)}
              />

              <div className="file-chips" style={{ marginBottom: 0 }}>
                <div className="file-chip">
                  📄 {pair.pdf ? pair.pdf.name : 'No PDF selected'}
                </div>
                <div className="file-chip">
                  💻 {pair.fortran ? pair.fortran.name : 'No Fortran selected'}
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="flex gap-1 mt-1">
          <button
            className="btn btn-sm"
            style={{ opacity: 0.8 }}
            disabled={processing}
            onClick={addEmptyPair}
          >
            + Add Pair
          </button>
          <button
            className="btn btn-sm"
            style={{ opacity: 0.8 }}
            disabled={processing}
            onClick={() => {
              setDraftPairs([{ id: makePairId(), pdf: null, fortran: null }]);
              setUploadQueue([]);
              setStatus({ type: '', msg: '' });
            }}
          >
            Reset Pairs
          </button>
        </div>

        {hasOrphanFortran && (
          <p className="status-message error">
            ✗ One or more rows have a Fortran file but no PDF — add a PDF or remove the row.
          </p>
        )}

        <button
          id="btn-upload"
          className="btn btn-primary upload-primary-action"
          disabled={uploadablePairCount === 0 || hasOrphanFortran || processing}
          onClick={handleUpload}
        >
          {processing
            ? <><span className="spinner" /> Processing Queue…</>
            : `⬆ Upload & Ingest (${uploadablePairCount} paper${uploadablePairCount !== 1 ? 's' : ''})`}
        </button>

        {processing && (
          <div className="progress-bar-container">
            <div className="progress-bar" />
          </div>
        )}

        {uploadQueue.length > 0 && (
          <div className="upload-queue mt-2">
            <h3 className="card-title" style={{ marginBottom: '0.5rem', fontSize: '0.95rem' }}>
              Processing Status
            </h3>
            {uploadQueue.map((item) => (
              <div className="queue-item" key={item.id}>
                <div className="queue-item-main">
                  <span className="queue-files">{item.pdfName} + {item.fortranName}</span>
                  <span className={`queue-state ${item.status}`}>{item.status}</span>
                </div>
                <div className="queue-message">{item.message}</div>
              </div>
            ))}
          </div>
        )}

        {status.msg && (
          <p className={`status-message ${status.type}`}>
            {status.type === 'success' && '✓ '}
            {status.type === 'error' && '✗ '}
            {status.msg}
          </p>
        )}
      </div>

      {/* ── Papers List ────────────────────────────────────────────────── */}
      <div className="card mt-3">
        <div className="flex items-center justify-between">
          <h2 className="card-title" style={{ marginBottom: 0 }}>Papers in Database</h2>
          <span style={{ color: 'var(--text-muted)', fontSize: '0.82rem' }}>
            {papers.length} paper{papers.length !== 1 ? 's' : ''}
          </span>
        </div>

        {loading ? (
          <div className="empty-state">
            <span className="spinner" />
          </div>
        ) : papers.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon">📭</div>
            <p className="empty-state-text">No papers yet — upload your first one above.</p>
          </div>
        ) : (
          <table className="paper-table">
            <thead>
              <tr>
                <th>Title</th>
                <th>Authors</th>
                <th>Added</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {papers.map((p) => (
                <tr key={p.paper_title}>
                  <td className="paper-title-cell">{p.paper_title}</td>
                  <td>{p.authors}</td>
                  <td className="paper-date">{formatDate(p.ingest_date)}</td>
                  <td>
                    <button
                      className="btn btn-danger btn-sm"
                      disabled={deleting === p.paper_title || processing}
                      onClick={() => handleDelete(p.paper_title)}
                    >
                      {deleting === p.paper_title ? <span className="spinner" /> : '🗑 Remove'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
