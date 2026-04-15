import { useEffect, useRef, useState, type FormEvent } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import renderMathInElement from 'katex/contrib/auto-render';
import { runQuery } from '../api';
import type { ChunkSource, CommunityContribution, GraphStatus, QueryMode } from '../types';

interface QueryTabProps {
  status: GraphStatus | null;
  isBlocked: boolean;
}

function normalizeMathMarkdown(text: string): string {
  return text
    .replace(/\\\$/g, '$')
    .replace(/\\\[((?:.|\n)*?)\\\]/g, '\n$$\n$1\n$$\n')
    .replace(/\\\(((?:.|\n)*?)\\\)/g, '$$$1$')
    .replace(/\$\$([\s\S]*?)\$\$/g, (_, expr: string) => `$$\n${expr.trim()}\n$$`)
    .replace(/\$([^\n$]+?)\$/g, (_, expr: string) => `$${expr.trim()}$`);
}

const markdownMathPlugins: any[] = [[remarkMath as any, { singleDollarTextMath: true }]];

const MODE_LABEL: Record<QueryMode, string> = {
  auto: 'Auto',
  local: 'Local',
  global: 'Global',
};

const MODE_HINT: Record<QueryMode, string> = {
  auto: 'Heuristic picks local vs global based on the question wording.',
  local: 'Entity-anchored: seeds → subgraph → chunks. Good for focused questions.',
  global: 'Map-reduce over community summaries. Good for comparative questions.',
};

export default function QueryTab({ status, isBlocked }: QueryTabProps) {
  const [query, setQuery] = useState('');
  const [mode, setMode] = useState<QueryMode>('auto');
  const [answer, setAnswer] = useState('');
  const [answerMode, setAnswerMode] = useState<QueryMode | null>(null);
  const [seeds, setSeeds] = useState<string[]>([]);
  const [subgraphNodes, setSubgraphNodes] = useState<string[]>([]);
  const [chunks, setChunks] = useState<ChunkSource[]>([]);
  const [communities, setCommunities] = useState<CommunityContribution[]>([]);
  const [candidateCount, setCandidateCount] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showEvidence, setShowEvidence] = useState(false);
  const answerContentRef = useRef<HTMLDivElement | null>(null);
  const evidenceRef = useRef<HTMLDivElement | null>(null);

  const isReady = status?.built === true;

  const resetResults = () => {
    setAnswer('');
    setAnswerMode(null);
    setSeeds([]);
    setSubgraphNodes([]);
    setChunks([]);
    setCommunities([]);
    setCandidateCount(null);
    setShowEvidence(false);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (isBlocked) {
      setError('A long-running task is active. Wait for it to finish.');
      return;
    }
    if (!isReady) {
      setError('Graph is not built yet. Build it from the Graph tab first.');
      return;
    }
    if (!query.trim() || loading) return;

    setLoading(true);
    setError('');
    resetResults();

    try {
      const res = await runQuery({ query: query.trim(), mode });
      setAnswer(res.answer || '');
      setAnswerMode(res.mode ?? null);
      setSeeds(res.seeds ?? []);
      setSubgraphNodes(res.subgraph_nodes ?? []);
      setChunks(res.chunks ?? []);
      setCommunities(res.communities ?? []);
      setCandidateCount(res.candidate_count ?? null);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Query failed');
    } finally {
      setLoading(false);
    }
  };

  const renderedAnswer = normalizeMathMarkdown(answer);

  useEffect(() => {
    const renderMath = (el: HTMLDivElement | null) => {
      if (!el) return;
      renderMathInElement(el, {
        delimiters: [
          { left: '$$', right: '$$', display: true },
          { left: '\\[', right: '\\]', display: true },
          { left: '$', right: '$', display: false },
          { left: '\\(', right: '\\)', display: false },
        ],
        throwOnError: false,
      });
    };

    renderMath(answerContentRef.current);
    if (showEvidence) {
      renderMath(evidenceRef.current);
    }
  }, [renderedAnswer, showEvidence]);

  const badgeClass = (type: string) => {
    const map: Record<string, string> = {
      manuscript: 'manuscript',
      fortran_function: 'fortran_function',
      fortran_section: 'fortran_function',
      fortran_architecture: 'fortran_function',
      equation: 'equation',
      table: 'table',
      image: 'image',
      paper_profile: 'paper_profile',
    };
    return map[type] || 'manuscript';
  };

  const isGlobalAnswer = answerMode === 'global' || (answerMode === null && communities.length > 0);
  const evidenceCount = isGlobalAnswer ? communities.length : chunks.length;
  const evidenceLabel = isGlobalAnswer
    ? `${communities.length} community contribution${communities.length !== 1 ? 's' : ''}`
    : `${chunks.length} chunk${chunks.length !== 1 ? 's' : ''} from ${subgraphNodes.length} entit${subgraphNodes.length === 1 ? 'y' : 'ies'}`;

  return (
    <div>
      <div className="card">
        <h2 className="card-title">Ask a Question</h2>

        <div className="flex items-center gap-1" style={{ marginBottom: '0.75rem', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Mode:</span>
          <div className="mode-select">
            {(['auto', 'local', 'global'] as QueryMode[]).map((m) => (
              <button
                type="button"
                key={m}
                className={mode === m ? 'active' : ''}
                disabled={loading || isBlocked}
                onClick={() => setMode(m)}
              >
                {MODE_LABEL[m]}
              </button>
            ))}
          </div>
          <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
            {MODE_HINT[mode]}
          </span>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="query-input-group">
            <input
              className="query-input"
              type="text"
              placeholder={
                mode === 'global'
                  ? 'e.g. Which papers use similar mathematical models?'
                  : 'e.g. How does the life-cycle model handle idiosyncratic risk?'
              }
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              disabled={loading || isBlocked || !isReady}
            />
            <button
              className="btn btn-primary"
              type="submit"
              disabled={!query.trim() || loading || isBlocked || !isReady}
            >
              {loading ? <><span className="spinner" /> Thinking…</> : '🔍 Search'}
            </button>
          </div>
        </form>

        {!isReady && (
          <p className="status-message">
            ⏳ Graph is not built yet. Go to the <strong>Graph</strong> tab to build it.
          </p>
        )}
        {isBlocked && isReady && (
          <p className="status-message">
            ⏳ Query is temporarily disabled while another task is running.
          </p>
        )}
        {loading && (
          <div className="progress-bar-container">
            <div className="progress-bar" />
          </div>
        )}
        {error && <p className="status-message error">✗ {error}</p>}
      </div>

      {/* ── Answer ──────────────────────────────────────────────── */}
      {answer && (
        <div className="card mt-3 answer-block">
          <div className="flex items-center justify-between" style={{ marginBottom: '0.5rem' }}>
            <h2 className="card-title" style={{ marginBottom: 0 }}>Answer</h2>
            {answerMode && (
              <span className="source-badge paper_profile">
                {answerMode} mode
              </span>
            )}
          </div>

          <div className="answer-content" ref={answerContentRef}>
            <ReactMarkdown remarkPlugins={markdownMathPlugins} rehypePlugins={[rehypeKatex]}>
              {renderedAnswer}
            </ReactMarkdown>
          </div>

          {/* Local metadata: seeds */}
          {!isGlobalAnswer && seeds.length > 0 && (
            <div style={{ marginTop: '1rem' }}>
              <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '0.35rem' }}>
                Seed entities extracted from your question:
              </div>
              <div className="community-entities">
                {seeds.map((s) => (
                  <span className="entity-chip" key={s}>{s}</span>
                ))}
              </div>
            </div>
          )}

          {/* Global metadata: candidates count */}
          {isGlobalAnswer && candidateCount !== null && (
            <p className="status-message" style={{ marginTop: '1rem', marginBottom: 0 }}>
              Inspected {candidateCount} community candidate{candidateCount !== 1 ? 's' : ''}; kept {communities.length} contribution{communities.length !== 1 ? 's' : ''}.
            </p>
          )}

          {evidenceCount > 0 && (
            <>
              <button
                className="sources-toggle"
                onClick={() => setShowEvidence((v) => !v)}
              >
                {showEvidence ? '▾' : '▸'} {evidenceLabel}
              </button>

              {showEvidence && (
                <div className="sources-list" ref={evidenceRef}>
                  {/* Global: community contributions */}
                  {isGlobalAnswer && communities.map((c) => (
                    <div className="source-item" key={c.community_id}>
                      <div className="source-meta">
                        <span className="source-badge community">
                          [Cm-{c.community_id}]
                        </span>
                        <span className="source-score">{c.title}</span>
                        <span className="source-score">score: {c.score}</span>
                      </div>
                      {c.theme && (
                        <div className="community-theme" style={{ marginBottom: '0.25rem' }}>
                          Theme: {c.theme}
                        </div>
                      )}
                      {c.contribution && (
                        <div className="source-text">
                          <ReactMarkdown remarkPlugins={markdownMathPlugins} rehypePlugins={[rehypeKatex]}>
                            {normalizeMathMarkdown(c.contribution)}
                          </ReactMarkdown>
                        </div>
                      )}
                      {c.papers && c.papers.length > 0 && (
                        <div style={{ marginTop: '0.4rem', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                          Papers: {c.papers.join(', ')}
                        </div>
                      )}
                    </div>
                  ))}

                  {/* Local: chunks */}
                  {!isGlobalAnswer && chunks.map((s, i) => {
                    const contentType = s.metadata?.content_type || 'unknown';
                    return (
                      <div className="source-item" key={s.id || i}>
                        <div className="source-meta">
                          <span className={`source-badge ${badgeClass(contentType)}`}>
                            [C{i + 1}] {contentType}
                          </span>
                          {s.metadata?.paper_title && (
                            <span className="source-score">{s.metadata.paper_title}</span>
                          )}
                          {s.metadata?.section && (
                            <span className="source-score">{s.metadata.section}</span>
                          )}
                        </div>
                        {contentType === 'table' && s.metadata?.table_body && (
                          <div
                            className="source-table"
                            dangerouslySetInnerHTML={{ __html: s.metadata.table_body }}
                          />
                        )}
                        <div className="source-text">
                          <ReactMarkdown remarkPlugins={markdownMathPlugins} rehypePlugins={[rehypeKatex]}>
                            {normalizeMathMarkdown(s.text)}
                          </ReactMarkdown>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}
