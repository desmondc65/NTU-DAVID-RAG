import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type FormEvent,
  type KeyboardEvent,
} from 'react';
import ReactMarkdown from 'react-markdown';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import renderMathInElement from 'katex/contrib/auto-render';
import { queryRAG } from '../api';
import type { ChatTurn, SourceItem } from '../types';

interface QueryTabProps {
  isBlocked: boolean;
}

interface AssistantMessage {
  id: string;
  role: 'assistant';
  content: string;
  sources: SourceItem[];
  pending?: boolean;
  errored?: boolean;
}

interface UserMessage {
  id: string;
  role: 'user';
  content: string;
}

type ChatMessage = UserMessage | AssistantMessage;

const STORAGE_KEY = 'econ-rag.chat.v1';
const TOP_K_STORAGE_KEY = 'econ-rag.topK.v1';
const HISTORY_TURNS_LIMIT = 30;

function normalizeMathMarkdown(text: string): string {
  return text
    .replace(/\\\$/g, '$')
    .replace(/\\\[((?:.|\n)*?)\\\]/g, '\n$$\n$1\n$$\n')
    .replace(/\\\(((?:.|\n)*?)\\\)/g, '$$$1$')
    .replace(/\$\$([\s\S]*?)\$\$/g, (_, expr: string) => `$$\n${expr.trim()}\n$$`)
    .replace(/\$([^\n$]+?)\$/g, (_, expr: string) => `$${expr.trim()}$`);
}

/**
 * Strip whitespace, normalise greek/latex/unicode equivalents, and lowercase
 * — used to detect when the model wrote the same value twice in two
 * notations (e.g. "$\gamma$" and "γ"). Order of replacements matters.
 */
const _GREEK_LATEX_TO_UNICODE: Array<[RegExp, string]> = [
  [/\\alpha/gi, 'α'], [/\\beta/gi, 'β'], [/\\gamma/gi, 'γ'], [/\\delta/gi, 'δ'],
  [/\\epsilon/gi, 'ε'], [/\\zeta/gi, 'ζ'], [/\\eta/gi, 'η'], [/\\theta/gi, 'θ'],
  [/\\iota/gi, 'ι'], [/\\kappa/gi, 'κ'], [/\\lambda/gi, 'λ'], [/\\mu/gi, 'μ'],
  [/\\nu/gi, 'ν'], [/\\xi/gi, 'ξ'], [/\\pi/gi, 'π'], [/\\rho/gi, 'ρ'],
  [/\\sigma/gi, 'σ'], [/\\tau/gi, 'τ'], [/\\upsilon/gi, 'υ'], [/\\phi/gi, 'φ'],
  [/\\chi/gi, 'χ'], [/\\psi/gi, 'ψ'], [/\\omega/gi, 'ω'],
];

function canonicaliseValueForDedupe(s: string): string {
  let out = s.trim();
  // Unwrap math delimiters.
  out = out.replace(/^\$+\s*/, '').replace(/\s*\$+$/, '');
  out = out.replace(/^\\\(\s*/, '').replace(/\s*\\\)$/, '');
  out = out.replace(/^\\\[\s*/, '').replace(/\s*\\\]$/, '');
  for (const [rx, replacement] of _GREEK_LATEX_TO_UNICODE) {
    out = out.replace(rx, replacement);
  }
  // Strip remaining backslashes + whitespace + common decorations so that
  // "\gamma" vs "γ" and "2.0 " vs "2.0" hash equal.
  out = out.replace(/[\\\s]/g, '').toLowerCase();
  return out;
}

/**
 * Collapse the LLM's bad habit of writing each value twice — once as LaTeX
 * and once as Unicode — typically separated by a newline:
 *   "...risk aversion of $2.0$\n2.0 (referred to as ...".
 * We also collapse the same pattern on a single line ("$2.0$ 2.0").
 */
function collapseDuplicateNotations(text: string): string {
  // Adjacent-line duplicates: line N's content == line N+1's leading token.
  const lines = text.split('\n');
  const cleaned: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const cur = lines[i];
    const trimmed = cur.trim();
    // A "value-only" line: math expression or short token, no sentence end.
    if (
      trimmed &&
      cleaned.length > 0 &&
      trimmed.length < 60 &&
      !/[.!?:;]\s*$/.test(cleaned[cleaned.length - 1])
    ) {
      const prev = cleaned[cleaned.length - 1];
      // Find the last whitespace-bounded token of the previous line.
      const prevMatch = prev.match(/(\S+)\s*$/);
      // Find the leading token of the current line.
      const curMatch = trimmed.match(/^(\S+)/);
      if (prevMatch && curMatch) {
        if (canonicaliseValueForDedupe(prevMatch[1]) === canonicaliseValueForDedupe(curMatch[1])) {
          // Drop the duplicated leading token from the current line.
          const rest = trimmed.replace(/^\S+\s*/, '');
          if (!rest) continue;
          cleaned.push(rest);
          continue;
        }
      }
    }
    cleaned.push(cur);
  }
  let joined = cleaned.join('\n');
  // Same-line duplicates: "$2.0$ 2.0" -> "$2.0$".
  joined = joined.replace(/(\$[^\n$]+\$)\s+(\S+)/g, (m, math, plain) => {
    return canonicaliseValueForDedupe(math) === canonicaliseValueForDedupe(plain)
      ? math
      : m;
  });
  return joined;
}

const markdownMathPlugins: any[] = [[remarkMath as any, { singleDollarTextMath: true }]];

function makeId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function badgeClass(type: string): string {
  const map: Record<string, string> = {
    manuscript: 'manuscript',
    fortran_function: 'fortran_function',
    fortran_section: 'fortran_function',
    fortran_architecture: 'fortran_function',
    equation: 'equation',
    table: 'table',
    image: 'image',
  };
  return map[type] || 'manuscript';
}

function loadStoredMessages(): ChatMessage[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((m): m is ChatMessage =>
      m && typeof m === 'object' && (m.role === 'user' || m.role === 'assistant'),
    );
  } catch {
    return [];
  }
}

function loadStoredTopK(): number {
  if (typeof window === 'undefined') return 10;
  const raw = window.localStorage.getItem(TOP_K_STORAGE_KEY);
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : 10;
}

function buildHistoryFromMessages(messages: ChatMessage[]): ChatTurn[] {
  const turns: ChatTurn[] = [];
  for (const m of messages) {
    if (m.role === 'user') {
      turns.push({ role: 'user', content: m.content });
    } else if (m.role === 'assistant' && m.content && !m.errored) {
      turns.push({ role: 'assistant', content: m.content });
    }
  }
  return turns.slice(-HISTORY_TURNS_LIMIT);
}

function exportConversationToMarkdown(messages: ChatMessage[]): string {
  const lines: string[] = ['# Econ-RAG conversation', ''];
  for (const m of messages) {
    if (m.role === 'user') {
      lines.push(`## You`, '', m.content, '');
    } else {
      lines.push(`## Assistant`, '', m.content, '');
      if (m.sources.length) {
        lines.push(`<details><summary>${m.sources.length} retrieved source(s)</summary>`, '');
        m.sources.forEach((s, i) => {
          const t = s.metadata?.content_type || 'unknown';
          const paper = s.metadata?.paper_title ? ` — ${s.metadata.paper_title}` : '';
          lines.push(`**[${i + 1}] ${t}${paper}**`, '', `> ${s.text.replace(/\n/g, '\n> ')}`, '');
        });
        lines.push('</details>', '');
      }
    }
  }
  return lines.join('\n');
}

function downloadFile(filename: string, content: string, mime = 'text/markdown'): void {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export default function QueryTab({ isBlocked }: QueryTabProps) {
  const [messages, setMessages] = useState<ChatMessage[]>(() => loadStoredMessages());
  const [draft, setDraft] = useState('');
  const [topK, setTopK] = useState<number>(() => loadStoredTopK());
  const [showSettings, setShowSettings] = useState(false);
  const [openSources, setOpenSources] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const threadRef = useRef<HTMLDivElement | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);

  const suggestions = useMemo(
    () => [
      'What drives wealth concentration in the United States?',
      'Compare the calibration choices in the two life-cycle papers.',
      'Show me the equation for the Bellman update used here.',
      'Which papers use a stochastic process for labor income, and how do they parameterise it?',
    ],
    [],
  );

  // Persist on every change.
  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(messages));
    } catch {
      /* quota / privacy mode — ignore */
    }
  }, [messages]);

  useEffect(() => {
    window.localStorage.setItem(TOP_K_STORAGE_KEY, String(topK));
  }, [topK]);

  // Auto-scroll to bottom when messages or loading state change.
  useEffect(() => {
    const el = threadRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [messages, loading]);

  // Auto-grow textarea.
  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 240)}px`;
  }, [draft]);

  // Render KaTeX as a safety net over text that ReactMarkdown's remark-math
  // didn't catch (e.g. raw HTML from sources). Skip already-rendered KaTeX
  // and code blocks to avoid double-rendering.
  useEffect(() => {
    const el = threadRef.current;
    if (!el) return;
    renderMathInElement(el, {
      delimiters: [
        { left: '$$', right: '$$', display: true },
        { left: '\\[', right: '\\]', display: true },
        { left: '$', right: '$', display: false },
        { left: '\\(', right: '\\)', display: false },
      ],
      // The runtime accepts these guards even though the TS types omit them.
      ignoredClasses: ['katex', 'katex-mathml', 'katex-html', 'chat-user-text'],
      ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code', 'option', 'annotation'],
      throwOnError: false,
    } as unknown as Parameters<typeof renderMathInElement>[1]);
  }, [messages, openSources]);

  const runQueryFor = useCallback(
    async (
      userMessageId: string,
      assistantMessageId: string,
      historyForRequest: ChatTurn[],
      questionContent: string,
    ) => {
      setError('');
      setLoading(true);
      const controller = new AbortController();
      abortRef.current = controller;
      try {
        const res = await queryRAG(questionContent, topK, historyForRequest, controller.signal);
        setMessages((prev) =>
          prev.map((m) =>
            m.id === assistantMessageId && m.role === 'assistant'
              ? { ...m, content: res.answer || '', sources: res.sources || [], pending: false }
              : m,
          ),
        );
      } catch (err: unknown) {
        if ((err as { name?: string })?.name === 'AbortError') {
          // Drop the placeholder pair on cancel so the chat stays consistent.
          setMessages((prev) =>
            prev.filter((m) => m.id !== userMessageId && m.id !== assistantMessageId),
          );
        } else {
          const msg = err instanceof Error ? err.message : 'Query failed';
          setError(msg);
          setMessages((prev) =>
            prev.map((m) =>
              m.id === assistantMessageId && m.role === 'assistant'
                ? {
                    ...m,
                    content: `**Request failed:** ${msg}`,
                    sources: [],
                    pending: false,
                    errored: true,
                  }
                : m,
            ),
          );
        }
      } finally {
        if (abortRef.current === controller) {
          abortRef.current = null;
        }
        setLoading(false);
      }
    },
    [topK],
  );

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (isBlocked) {
      setError('Ingestion is currently running. Wait for all files to finish processing.');
      return;
    }
    const content = draft.trim();
    if (!content || loading) return;

    const userMessage: UserMessage = { id: makeId(), role: 'user', content };
    const assistantMessage: AssistantMessage = {
      id: makeId(),
      role: 'assistant',
      content: '',
      sources: [],
      pending: true,
    };
    const next = [...messages, userMessage, assistantMessage];
    setMessages(next);
    setDraft('');

    const historyForRequest = buildHistoryFromMessages([
      ...messages,
      userMessage,
    ]);
    runQueryFor(userMessage.id, assistantMessage.id, historyForRequest, content);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault();
      handleSubmit(e as unknown as FormEvent);
    }
  };

  const stopRequest = () => {
    abortRef.current?.abort();
  };

  const startNewChat = () => {
    if (loading) {
      stopRequest();
    }
    if (
      messages.length > 0 &&
      !window.confirm('Start a new chat? The current conversation will be cleared.')
    ) {
      return;
    }
    setMessages([]);
    setOpenSources({});
    setError('');
  };

  const exportMarkdown = () => {
    if (messages.length === 0) return;
    downloadFile(`econ-rag-chat-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.md`,
      exportConversationToMarkdown(messages));
  };

  const copyToClipboard = async (text: string, messageId?: string) => {
    try {
      await navigator.clipboard.writeText(text);
      if (messageId) {
        setCopiedId(messageId);
        window.setTimeout(() => {
          setCopiedId((curr) => (curr === messageId ? null : curr));
        }, 1500);
      }
    } catch {
      // Best-effort fallback — silently noop on secure-context errors.
    }
  };

  const sendSuggestion = (text: string) => {
    setDraft(text);
    // Move focus to the composer so the user can edit or just press Enter.
    requestAnimationFrame(() => textareaRef.current?.focus());
  };

  const regenerateLast = () => {
    if (loading) return;
    // Find last assistant message and the preceding user message.
    const lastAssistantIdx = [...messages].reverse().findIndex((m) => m.role === 'assistant');
    if (lastAssistantIdx < 0) return;
    const realIdx = messages.length - 1 - lastAssistantIdx;
    const assistantMsg = messages[realIdx];
    let userMsg: UserMessage | null = null;
    for (let i = realIdx - 1; i >= 0; i--) {
      if (messages[i].role === 'user') {
        userMsg = messages[i] as UserMessage;
        break;
      }
    }
    if (!userMsg || assistantMsg.role !== 'assistant') return;

    const historyForRequest = buildHistoryFromMessages(messages.slice(0, realIdx));
    setMessages((prev) =>
      prev.map((m) =>
        m.id === assistantMsg.id && m.role === 'assistant'
          ? { ...m, content: '', sources: [], pending: true, errored: false }
          : m,
      ),
    );
    runQueryFor(userMsg.id, assistantMsg.id, historyForRequest, userMsg.content);
  };

  const deleteFromMessage = (id: string) => {
    const idx = messages.findIndex((m) => m.id === id);
    if (idx < 0) return;
    setMessages((prev) => prev.slice(0, idx));
  };

  const historyChars = useMemo(
    () => messages.reduce((acc, m) => acc + (m.content?.length || 0), 0),
    [messages],
  );

  return (
    <div className="chat-shell">
      <header className="chat-header">
        <div className="chat-header-left">
          <span className="chat-title-text">Research Chat</span>
          <span className="chat-meta-inline">
            {messages.length === 0
              ? 'No messages yet'
              : `${messages.length} message${messages.length === 1 ? '' : 's'} · ~${historyChars.toLocaleString()} chars`}
          </span>
        </div>
        <div className="chat-header-actions">
          <button
            className="btn btn-small"
            type="button"
            onClick={() => setShowSettings((v) => !v)}
            title="Show settings"
          >
            ⚙ Settings
          </button>
          <button
            className="btn btn-small"
            type="button"
            onClick={exportMarkdown}
            disabled={messages.length === 0}
            title="Export the conversation as Markdown"
          >
            ⬇ Export
          </button>
          <button
            className="btn btn-small"
            type="button"
            onClick={startNewChat}
            disabled={isBlocked && !loading}
            title="Start a new chat (clears history)"
          >
            ✦ New chat
          </button>
        </div>
      </header>

      {showSettings && (
        <div className="chat-settings">
          <label className="chat-setting">
            <span>Sources retrieved per question (top-K)</span>
            <input
              type="number"
              min={1}
              max={50}
              value={topK}
              onChange={(e) => setTopK(Math.max(1, Math.min(50, Number(e.target.value) || 10)))}
            />
          </label>
          <p className="chat-setting-hint">
            Conversation history (last {HISTORY_TURNS_LIMIT} turns) is replayed to the model on every question, so follow-up questions pick up where you left off.
          </p>
        </div>
      )}

      <div className="chat-thread" ref={threadRef}>
        {messages.length === 0 && !loading && (
          <div className="chat-empty">
            <p className="chat-empty-title">Ask the corpus anything.</p>
            <p className="chat-empty-hint">
              Tap a suggestion to get started, or type your own question below.
            </p>
            <div className="chat-suggestions">
              {suggestions.map((s) => (
                <button
                  key={s}
                  type="button"
                  className="chat-suggestion"
                  onClick={() => sendSuggestion(s)}
                  disabled={isBlocked}
                >
                  {s}
                </button>
              ))}
            </div>
            <p className="chat-empty-hint" style={{ marginTop: '1.4rem' }}>
              Press <kbd>Enter</kbd> to send · <kbd>Shift</kbd>+<kbd>Enter</kbd> for a new line.
            </p>
          </div>
        )}

        {messages.map((m, idx) => {
          const isUser = m.role === 'user';
          const isPending = m.role === 'assistant' && m.pending;
          const sourcesOpen = openSources[m.id] ?? false;
          const isCopied = copiedId === m.id;
          const isLastAssistant =
            !isUser && idx === messages.length - 1 && m.role === 'assistant' && !m.pending;
          return (
            <div className={`chat-row ${isUser ? 'is-user' : 'is-assistant'}`} key={m.id}>
              <div className="chat-row-meta">
                <span className="chat-role-tag">{isUser ? 'You' : 'Assistant'}</span>
              </div>

              <div className="chat-bubble">
                {isPending ? (
                  <span className="chat-typing">
                    <span className="spinner" /> Thinking…
                  </span>
                ) : isUser ? (
                  <div className="chat-user-text">{m.content}</div>
                ) : (
                  <ReactMarkdown
                    remarkPlugins={markdownMathPlugins}
                    rehypePlugins={[rehypeKatex]}
                  >
                    {normalizeMathMarkdown(collapseDuplicateNotations(m.content))}
                  </ReactMarkdown>
                )}
              </div>

              {!isUser && !isPending && m.sources.length > 0 && (
                <>
                  <button
                    className="chat-sources-chip"
                    onClick={() =>
                      setOpenSources((prev) => ({ ...prev, [m.id]: !prev[m.id] }))
                    }
                  >
                    {sourcesOpen ? '▾' : '▸'} sources
                    <span className="pill-count">{m.sources.length}</span>
                  </button>
                  {sourcesOpen && (
                    <div className="chat-sources-panel sources-list">
                      {m.sources.map((s, i) => {
                        const contentType = s.metadata?.content_type || 'unknown';
                        return (
                          <div className="source-item" key={i}>
                            <div className="source-meta">
                              <span className={`source-badge ${badgeClass(contentType)}`}>
                                {contentType}
                              </span>
                              {s.metadata?.paper_title && (
                                <span className="source-score">{s.metadata.paper_title}</span>
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
                            {contentType === 'table' && s.metadata?.table_body && (
                              <div
                                className="source-table"
                                dangerouslySetInnerHTML={{ __html: s.metadata.table_body }}
                              />
                            )}
                            <div className="source-text">
                              <ReactMarkdown
                                remarkPlugins={markdownMathPlugins}
                                rehypePlugins={[rehypeKatex]}
                              >
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

              {!isPending && (
                <div className="chat-actions">
                  <button
                    type="button"
                    className="chat-action-btn"
                    title="Copy message text"
                    onClick={() => copyToClipboard(m.content, m.id)}
                  >
                    {isCopied ? <span className="copied">✓ Copied</span> : <>⧉ Copy</>}
                  </button>
                  {isLastAssistant && (
                    <button
                      type="button"
                      className="chat-action-btn"
                      title="Regenerate this answer"
                      onClick={regenerateLast}
                      disabled={loading || isBlocked}
                    >
                      ↻ Regenerate
                    </button>
                  )}
                  <button
                    type="button"
                    className="chat-action-btn danger"
                    title="Delete this and all later messages"
                    onClick={() => deleteFromMessage(m.id)}
                    disabled={loading}
                  >
                    ✕ Delete
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {error && <p className="chat-status error">✗ {error}</p>}
      {isBlocked && !loading && (
        <p className="chat-status">
          ⏳ Query is temporarily disabled while paper ingestion is processing.
        </p>
      )}

      <form className="chat-composer" onSubmit={handleSubmit}>
        <div className="chat-textarea-wrap">
          <textarea
            ref={textareaRef}
            className="chat-textarea"
            placeholder={
              isBlocked
                ? 'Ingestion is processing — please wait…'
                : 'Ask a question about the papers…'
            }
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={isBlocked}
            rows={1}
          />
        </div>
        {loading ? (
          <button
            type="button"
            className="chat-send-btn is-stop"
            onClick={stopRequest}
            title="Stop generating"
          >
            ■ Stop
          </button>
        ) : (
          <button
            type="submit"
            className="chat-send-btn"
            disabled={!draft.trim() || isBlocked}
            title="Send (Enter)"
          >
            Send ▸
          </button>
        )}
      </form>
    </div>
  );
}
