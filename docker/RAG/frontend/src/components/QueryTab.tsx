import { useEffect, useRef, useState, type FormEvent } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import renderMathInElement from 'katex/contrib/auto-render';
import { queryRAG } from '../api';
import type { ChatTurn, SourceItem } from '../types';

interface QueryTabProps {
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

export default function QueryTab({ isBlocked }: QueryTabProps) {
  const [query, setQuery] = useState('');
  const [answer, setAnswer] = useState('');
  const [sources, setSources] = useState<SourceItem[]>([]);
  const [conversationHistory, setConversationHistory] = useState<ChatTurn[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showSources, setShowSources] = useState(false);
  const answerContentRef = useRef<HTMLDivElement | null>(null);
  const sourcesListRef = useRef<HTMLDivElement | null>(null);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (isBlocked) {
      setError('Ingestion is currently running. Wait for all files to finish processing.');
      return;
    }
    if (!query.trim() || loading) return;

    setLoading(true);
    setError('');
    setAnswer('');
    setSources([]);
    setShowSources(false);

    try {
      const userTurn: ChatTurn = { role: 'user', content: query.trim() };
      const historyForRequest = [...conversationHistory, userTurn].slice(-20);
      const res = await queryRAG(query.trim(), 10, historyForRequest);
      const assistantTurn: ChatTurn = { role: 'assistant', content: res.answer };
      setAnswer(res.answer);
      setSources(res.sources);
      setConversationHistory((prev) => [...prev, userTurn, assistantTurn].slice(-20));
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Query failed');
    } finally {
      setLoading(false);
    }
  };

  const badgeClass = (type: string) => {
    const map: Record<string, string> = {
      manuscript: 'manuscript',
      fortran_function: 'fortran_function',
      equation: 'equation',
      table: 'table',
      image: 'image',
    };
    return map[type] || 'manuscript';
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
    if (showSources) {
      renderMath(sourcesListRef.current);
    }
  }, [renderedAnswer, showSources, sources]);

  return (
    <div>
      <div className="card">
        <h2 className="card-title">Ask a Question</h2>
        <form onSubmit={handleSubmit}>
          <div className="query-input-group">
            <input
              id="query-input"
              className="query-input"
              type="text"
              placeholder="e.g. What drives wealth concentration in the United States?"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              disabled={loading || isBlocked}
            />
            <button
              id="btn-query"
              className="btn btn-primary"
              type="submit"
              disabled={!query.trim() || loading || isBlocked}
            >
              {loading ? <><span className="spinner" /> Thinking…</> : '🔍 Search'}
            </button>
            <button
              className="btn"
              type="button"
              onClick={() => setConversationHistory([])}
              disabled={loading || isBlocked || conversationHistory.length === 0}
              title="Clear conversation memory for follow-up questions"
            >
              Clear history
            </button>
          </div>
        </form>

        {isBlocked && (
          <p className="status-message">
            ⏳ Query is temporarily disabled while paper ingestion is processing.
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
          <h2 className="card-title">Answer</h2>
          <div className="answer-content" ref={answerContentRef}>
            <ReactMarkdown remarkPlugins={markdownMathPlugins} rehypePlugins={[rehypeKatex]}>
              {renderedAnswer}
            </ReactMarkdown>
          </div>

          {sources.length > 0 && (
            <>
              <button
                className="sources-toggle"
                onClick={() => setShowSources(!showSources)}
              >
                {showSources ? '▾' : '▸'} {sources.length} source{sources.length !== 1 ? 's' : ''} retrieved
              </button>

              {showSources && (
                <div className="sources-list" ref={sourcesListRef}>
                  {sources.map((s, i) => {
                    const contentType = s.metadata?.content_type || 'unknown';
                    return (
                      <div className="source-item" key={i}>
                        <div className="source-meta">
                          <span className={`source-badge ${badgeClass(contentType)}`}>
                            {contentType}
                          </span>
                          {s.metadata?.paper_title && (
                            <span className="source-score">
                              {s.metadata.paper_title}
                            </span>
                          )}
                          <span className="source-score">
                            score: {typeof s.score === 'number' ? s.score.toFixed(4) : s.score}
                          </span>
                        </div>
                        {contentType === 'image' && s.metadata?.image_data_url && (
                          <img
                            className="source-image-preview"
                            src={s.metadata.image_data_url}
                            alt={s.metadata?.img_rel_path || 'Retrieved source image'}
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
