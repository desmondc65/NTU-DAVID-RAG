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
import {
  deleteMessage,
  fetchMessages,
  queryRAG,
  type ServerMessage,
} from '../api';
import type { SourceItem } from '../types';

interface QueryTabProps {
  isBlocked: boolean;
  activeConversationId: string | null;
  onConversationCreated: (id: string) => void;
  onConversationTouched: () => void;
}

interface AssistantMessage {
  id: string;               // server message id once persisted
  role: 'assistant';
  content: string;
  sources: SourceItem[];
  pending?: boolean;
  errored?: boolean;
  /** Temp id used only while the assistant reply is in-flight. */
  tempId?: string;
}

interface UserMessage {
  id: string;
  role: 'user';
  content: string;
  /** Temp id used only while the turn is in-flight. */
  tempId?: string;
}

type ChatMessage = UserMessage | AssistantMessage;

const TOP_K_STORAGE_KEY = 'econ-rag.topK.v1';

function normalizeMathMarkdown(text: string): string {
  return text
    .replace(/\\\$/g, '$')
    .replace(/\\\[((?:.|\n)*?)\\\]/g, '\n$$\n$1\n$$\n')
    .replace(/\\\(((?:.|\n)*?)\\\)/g, '$$$1$')
    .replace(/\$\$([\s\S]*?)\$\$/g, (_, expr: string) => `$$\n${expr.trim()}\n$$`)
    .replace(/\$([^\n$]+?)\$/g, (_, expr: string) => `$${expr.trim()}$`);
}

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
  out = out.replace(/^\$+\s*/, '').replace(/\s*\$+$/, '');
  out = out.replace(/^\\\(\s*/, '').replace(/\s*\\\)$/, '');
  out = out.replace(/^\\\[\s*/, '').replace(/\s*\\\]$/, '');
  for (const [rx, replacement] of _GREEK_LATEX_TO_UNICODE) {
    out = out.replace(rx, replacement);
  }
  out = out.replace(/[\\\s]/g, '').toLowerCase();
  return out;
}

function collapseDuplicateNotations(text: string): string {
  const lines = text.split('\n');
  const cleaned: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const cur = lines[i];
    const trimmed = cur.trim();
    if (
      trimmed &&
      cleaned.length > 0 &&
      trimmed.length < 60 &&
      !/[.!?:;]\s*$/.test(cleaned[cleaned.length - 1])
    ) {
      const prev = cleaned[cleaned.length - 1];
      const prevMatch = prev.match(/(\S+)\s*$/);
      const curMatch = trimmed.match(/^(\S+)/);
      if (prevMatch && curMatch) {
        if (canonicaliseValueForDedupe(prevMatch[1]) === canonicaliseValueForDedupe(curMatch[1])) {
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
  // LLMs frequently echo an inline math expression's value as plain
  // text right after it (e.g. "$2.5\%$2.5%", "$\lambda$λ", or with a
  // single space "$\lambda$ λ"). Without removing the echo, we end up
  // with "2.5%2.5%" / "λλ" once the math span renders next to it.
  //
  // Strategy: walk every "$math$<after>" occurrence; if the chars right
  // after the closing $ (after optional whitespace) start with the
  // canonicalised math content, drop just that prefix. We only strip
  // the prefix — anything past the duplicated chunk (punctuation, the
  // next sentence) is preserved verbatim.
  joined = joined.replace(/(\$[^\n$]+\$)([^\n$]*)/g, (m, math, after) => {
    if (!after) return m;
    const canon = canonicaliseValueForDedupe(math);
    if (!canon) return m;
    const leadingWsLen = after.length - after.replace(/^\s*/, '').length;
    const tail = after.slice(leadingWsLen);
    if (tail.toLowerCase().startsWith(canon)) {
      return math + after.slice(0, leadingWsLen) + tail.slice(canon.length);
    }
    return m;
  });
  return joined;
}

const markdownMathPlugins: any[] = [[remarkMath as any, { singleDollarTextMath: true }]];

function tempId(): string {
  return `tmp-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
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

function loadStoredTopK(): number {
  if (typeof window === 'undefined') return 10;
  const raw = window.localStorage.getItem(TOP_K_STORAGE_KEY);
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : 10;
}

function coerceSources(raw: unknown): SourceItem[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((r) => {
    if (!r || typeof r !== 'object') return [];
    const rec = r as Record<string, unknown>;
    const text = typeof rec.text === 'string' ? rec.text : '';
    const metadata = (rec.metadata && typeof rec.metadata === 'object')
      ? (rec.metadata as Record<string, string>)
      : {};
    const score = typeof rec.score === 'number' ? rec.score : Number(rec.score) || 0;
    return [{ text, metadata, score }];
  });
}

function serverToChat(msg: ServerMessage): ChatMessage | null {
  if (msg.role === 'user') {
    return { id: msg.id, role: 'user', content: msg.content };
  }
  if (msg.role === 'assistant') {
    return {
      id: msg.id,
      role: 'assistant',
      content: msg.content,
      sources: coerceSources(msg.sources),
    };
  }
  return null;
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

export default function QueryTab({
  isBlocked,
  activeConversationId,
  onConversationCreated,
  onConversationTouched,
}: QueryTabProps) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [topK, setTopK] = useState<number>(() => loadStoredTopK());
  const [showSettings, setShowSettings] = useState(false);
  const [openSources, setOpenSources] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(false);
  const [loadingMessages, setLoadingMessages] = useState(false);
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

  // Load messages whenever the active conversation changes.
  useEffect(() => {
    let cancelled = false;
    if (!activeConversationId) {
      setMessages([]);
      setOpenSources({});
      return;
    }
    (async () => {
      setLoadingMessages(true);
      setError('');
      try {
        const rows = await fetchMessages(activeConversationId);
        if (cancelled) return;
        const mapped = rows
          .map(serverToChat)
          .filter((m): m is ChatMessage => m !== null);
        setMessages(mapped);
        setOpenSources({});
      } catch (err) {
        if (!cancelled) {
          setMessages([]);
          setError(err instanceof Error ? err.message : 'Failed to load messages');
        }
      } finally {
        if (!cancelled) setLoadingMessages(false);
      }
    })();
    return () => { cancelled = true; };
  }, [activeConversationId]);

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

  // KaTeX auto-render pass: rehype-katex via the markdown pipeline does
  // not consistently render every $..$ in this stack (observed: removing
  // this useEffect leaves the math raw and red), so we keep the DOM
  // post-pass as the actual renderer. ignoredClasses skips spans that
  // rehype-katex did manage to render so we don't double-process them.
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
      ignoredClasses: ['katex', 'katex-mathml', 'katex-html', 'chat-user-text'],
      ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code', 'option', 'annotation'],
      throwOnError: false,
    } as unknown as Parameters<typeof renderMathInElement>[1]);
  }, [messages, openSources]);

  const sendQuery = useCallback(
    async (questionContent: string) => {
      setError('');
      setLoading(true);

      const userTemp: UserMessage = {
        id: tempId(),
        tempId: tempId(),
        role: 'user',
        content: questionContent,
      };
      const assistantTemp: AssistantMessage = {
        id: tempId(),
        tempId: tempId(),
        role: 'assistant',
        content: '',
        sources: [],
        pending: true,
      };
      setMessages((prev) => [...prev, userTemp, assistantTemp]);

      const controller = new AbortController();
      abortRef.current = controller;

      try {
        const res = await queryRAG(
          {
            query: questionContent,
            top_k: topK,
            conversation_id: activeConversationId,
          },
          controller.signal,
        );

        const convId = res.conversation_id;
        const ids = res.message_ids;
        if (convId && convId !== activeConversationId) {
          onConversationCreated(convId);
        }
        onConversationTouched();

        setMessages((prev) =>
          prev.map((m) => {
            if (m.id === userTemp.id && ids?.user) {
              return { ...m, id: ids.user, tempId: undefined };
            }
            if (m.id === assistantTemp.id) {
              return {
                ...m,
                id: ids?.assistant || m.id,
                tempId: undefined,
                content: res.answer || '',
                sources: res.sources || [],
                pending: false,
              };
            }
            return m;
          }),
        );
      } catch (err: unknown) {
        if ((err as { name?: string })?.name === 'AbortError') {
          // Drop the placeholder pair. If the server persisted anyway the
          // next sidebar-triggered reload will surface them.
          setMessages((prev) =>
            prev.filter((m) => m.id !== userTemp.id && m.id !== assistantTemp.id),
          );
        } else {
          const msg = err instanceof Error ? err.message : 'Query failed';
          setError(msg);
          setMessages((prev) =>
            prev.map((m) =>
              m.id === assistantTemp.id && m.role === 'assistant'
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
        if (abortRef.current === controller) abortRef.current = null;
        setLoading(false);
      }
    },
    [topK, activeConversationId, onConversationCreated, onConversationTouched],
  );

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (isBlocked) {
      setError('Ingestion is currently running. Wait for all files to finish processing.');
      return;
    }
    const content = draft.trim();
    if (!content || loading) return;
    setDraft('');
    void sendQuery(content);
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
      /* noop */
    }
  };

  const sendSuggestion = (text: string) => {
    setDraft(text);
    requestAnimationFrame(() => textareaRef.current?.focus());
  };

  const regenerateLast = async () => {
    if (loading || !activeConversationId) return;

    // Find the last assistant + the preceding user message in local state.
    let lastAssistant: AssistantMessage | null = null;
    let lastUser: UserMessage | null = null;
    for (let i = messages.length - 1; i >= 0; i--) {
      const m = messages[i];
      if (!lastAssistant && m.role === 'assistant' && !m.pending) {
        lastAssistant = m;
        continue;
      }
      if (lastAssistant && m.role === 'user') {
        lastUser = m;
        break;
      }
    }
    if (!lastUser || !lastAssistant) return;

    // Soft-delete the old assistant message on the server, then replay the
    // user query. The server appends a fresh assistant reply.
    try {
      if (!lastAssistant.tempId) {
        await deleteMessage(activeConversationId, lastAssistant.id);
      }
      setMessages((prev) => prev.filter((m) => m.id !== lastAssistant!.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to drop previous answer');
      return;
    }

    await sendQuery(lastUser.content);
  };

  const deleteFromMessage = async (id: string) => {
    if (!activeConversationId) return;
    const idx = messages.findIndex((m) => m.id === id);
    if (idx < 0) return;
    const target = messages.slice(idx);
    // Soft-delete server-side messages one by one. Temp ids (in-flight) skip.
    try {
      for (const m of target) {
        if (m.tempId || !activeConversationId) continue;
        await deleteMessage(activeConversationId, m.id);
      }
      setMessages((prev) => prev.slice(0, idx));
      onConversationTouched();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Delete failed');
    }
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
            {loadingMessages
              ? 'Loading…'
              : messages.length === 0
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
            History is stored server-side per conversation; it's replayed into the model automatically on every follow-up.
          </p>
        </div>
      )}

      <div className="chat-thread" ref={threadRef}>
        {messages.length === 0 && !loading && !loadingMessages && (
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
                      onClick={() => void regenerateLast()}
                      disabled={loading || isBlocked}
                    >
                      ↻ Regenerate
                    </button>
                  )}
                  <button
                    type="button"
                    className="chat-action-btn danger"
                    title="Delete this and all later messages"
                    onClick={() => void deleteFromMessage(m.id)}
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
