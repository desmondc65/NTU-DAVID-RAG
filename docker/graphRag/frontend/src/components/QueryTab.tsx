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
  runQuery,
  type ServerMessage,
} from '../api';
import type {
  ChunkSource,
  CommunityContribution,
  GraphStatus,
  QueryMode,
} from '../types';

interface QueryTabProps {
  status: GraphStatus | null;
  isBlocked: boolean;
  activeConversationId: string | null;
  onConversationCreated: (id: string) => void;
  onConversationTouched: () => void;
}

interface UserMessage {
  id: string;
  role: 'user';
  content: string;
  mode: QueryMode;
  tempId?: string;
}

interface AssistantMessage {
  id: string;
  role: 'assistant';
  content: string;
  mode: QueryMode | null;
  seeds: string[];
  subgraphNodes: string[];
  chunks: ChunkSource[];
  communities: CommunityContribution[];
  candidateCount: number | null;
  rewrittenQuery: string | null;
  pending?: boolean;
  errored?: boolean;
  tempId?: string;
}

type ChatMessage = UserMessage | AssistantMessage;

const MODE_STORAGE_KEY = 'econ-graphrag.mode.v1';

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
  joined = joined.replace(/(\$[^\n$]+\$)\s+(\S+)/g, (m, math, plain) => {
    return canonicaliseValueForDedupe(math) === canonicaliseValueForDedupe(plain)
      ? math
      : m;
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
    paper_profile: 'paper_profile',
  };
  return map[type] || 'manuscript';
}

function loadStoredMode(): QueryMode {
  if (typeof window === 'undefined') return 'auto';
  const raw = window.localStorage.getItem(MODE_STORAGE_KEY);
  if (raw === 'local' || raw === 'global' || raw === 'auto') return raw;
  return 'auto';
}

function coerceChunks(raw: unknown): ChunkSource[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((r) => {
    if (!r || typeof r !== 'object') return [];
    const rec = r as Record<string, unknown>;
    const id = typeof rec.id === 'string' ? rec.id : '';
    const text = typeof rec.text === 'string' ? rec.text : '';
    const metadata = (rec.metadata && typeof rec.metadata === 'object')
      ? (rec.metadata as Record<string, string>)
      : {};
    return [{ id, text, metadata }];
  });
}

function coerceCommunities(raw: unknown): CommunityContribution[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((r) => {
    if (!r || typeof r !== 'object') return [];
    const rec = r as Record<string, unknown>;
    return [{
      community_id: Number(rec.community_id) || 0,
      title: typeof rec.title === 'string' ? rec.title : '',
      theme: typeof rec.theme === 'string' ? rec.theme : '',
      score: Number(rec.score) || 0,
      contribution: typeof rec.contribution === 'string' ? rec.contribution : '',
      papers: Array.isArray(rec.papers) ? rec.papers.filter((p): p is string => typeof p === 'string') : [],
    }];
  });
}

function coerceStringArray(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter((s): s is string => typeof s === 'string');
}

function coerceMode(raw: unknown): QueryMode | null {
  return raw === 'local' || raw === 'global' || raw === 'auto' ? raw : null;
}

function serverToChat(msg: ServerMessage): ChatMessage | null {
  if (msg.role === 'user') {
    const meta = msg.metadata || {};
    return {
      id: msg.id,
      role: 'user',
      content: msg.content,
      mode: coerceMode(meta.mode) ?? 'auto',
    };
  }
  if (msg.role === 'assistant') {
    const meta = msg.metadata || {};
    return {
      id: msg.id,
      role: 'assistant',
      content: msg.content,
      mode: coerceMode(meta.mode),
      seeds: coerceStringArray(meta.seeds),
      subgraphNodes: coerceStringArray(meta.subgraph_nodes),
      chunks: coerceChunks(msg.sources),
      communities: coerceCommunities(meta.communities),
      candidateCount: typeof meta.candidate_count === 'number' ? meta.candidate_count : null,
      rewrittenQuery: typeof meta.rewritten_query === 'string' ? meta.rewritten_query : null,
    };
  }
  return null;
}

function exportConversationToMarkdown(messages: ChatMessage[]): string {
  const lines: string[] = ['# Econ-GraphRAG conversation', ''];
  for (const m of messages) {
    if (m.role === 'user') {
      lines.push(`## You _(mode: ${m.mode})_`, '', m.content, '');
    } else {
      const modeNote = m.mode ? ` _(answered in ${m.mode} mode)_` : '';
      lines.push(`## Assistant${modeNote}`, '', m.content, '');
      if (m.communities.length) {
        lines.push(`<details><summary>${m.communities.length} community contribution(s)</summary>`, '');
        m.communities.forEach((c) => {
          lines.push(`**[Cm-${c.community_id}] ${c.title}** — score ${c.score}`, '');
          if (c.theme) lines.push(`*Theme:* ${c.theme}`, '');
          if (c.contribution) lines.push(`> ${c.contribution.replace(/\n/g, '\n> ')}`, '');
          if (c.papers?.length) lines.push(`*Papers:* ${c.papers.join(', ')}`, '');
        });
        lines.push('</details>', '');
      }
      if (m.chunks.length) {
        lines.push(`<details><summary>${m.chunks.length} chunk(s) from ${m.subgraphNodes.length} entit${m.subgraphNodes.length === 1 ? 'y' : 'ies'}</summary>`, '');
        m.chunks.forEach((c, i) => {
          const t = c.metadata?.content_type || 'unknown';
          const paper = c.metadata?.paper_title ? ` — ${c.metadata.paper_title}` : '';
          lines.push(`**[C${i + 1}] ${t}${paper}**`, '', `> ${c.text.replace(/\n/g, '\n> ')}`, '');
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
  status,
  isBlocked,
  activeConversationId,
  onConversationCreated,
  onConversationTouched,
}: QueryTabProps) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [mode, setMode] = useState<QueryMode>(() => loadStoredMode());
  const [draft, setDraft] = useState('');
  const [openEvidence, setOpenEvidence] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(false);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [error, setError] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const threadRef = useRef<HTMLDivElement | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);

  const suggestions = useMemo(
    () => [
      'How does the life-cycle model handle idiosyncratic risk?',
      'Which papers use similar mathematical models?',
      'Compare the calibration choices across the OLG papers.',
      'What entities are central to the wealth-inequality cluster?',
    ],
    [],
  );

  const isReady = status?.built === true;

  // Load messages whenever the active conversation changes.
  useEffect(() => {
    let cancelled = false;
    if (!activeConversationId) {
      setMessages([]);
      setOpenEvidence({});
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
        setOpenEvidence({});
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
    window.localStorage.setItem(MODE_STORAGE_KEY, mode);
  }, [mode]);

  useEffect(() => {
    const el = threadRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [messages, loading]);

  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 240)}px`;
  }, [draft]);

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
  }, [messages, openEvidence]);

  const sendQuery = useCallback(
    async (questionContent: string, requestMode: QueryMode) => {
      setError('');
      setLoading(true);

      const userTemp: UserMessage = {
        id: tempId(),
        tempId: tempId(),
        role: 'user',
        content: questionContent,
        mode: requestMode,
      };
      const assistantTemp: AssistantMessage = {
        id: tempId(),
        tempId: tempId(),
        role: 'assistant',
        content: '',
        mode: null,
        seeds: [],
        subgraphNodes: [],
        chunks: [],
        communities: [],
        candidateCount: null,
        rewrittenQuery: null,
        pending: true,
      };
      setMessages((prev) => [...prev, userTemp, assistantTemp]);

      const controller = new AbortController();
      abortRef.current = controller;
      try {
        const res = await runQuery(
          {
            query: questionContent,
            mode: requestMode,
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
                mode: res.mode ?? requestMode,
                seeds: res.seeds ?? [],
                subgraphNodes: res.subgraph_nodes ?? [],
                chunks: res.chunks ?? [],
                communities: res.communities ?? [],
                candidateCount: res.candidate_count ?? null,
                rewrittenQuery: res.rewritten_query ?? null,
                pending: false,
              };
            }
            return m;
          }),
        );
      } catch (err: unknown) {
        if ((err as { name?: string })?.name === 'AbortError') {
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
    [activeConversationId, onConversationCreated, onConversationTouched],
  );

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (isBlocked) {
      setError('A long-running task is active. Wait for it to finish.');
      return;
    }
    if (!isReady) {
      setError('Graph is not built yet. Build it from the Graph tab first.');
      return;
    }
    const content = draft.trim();
    if (!content || loading) return;
    setDraft('');
    void sendQuery(content, mode);
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
    downloadFile(
      `econ-graphrag-chat-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.md`,
      exportConversationToMarkdown(messages),
    );
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
      /* ignore */
    }
  };

  const sendSuggestion = (text: string) => {
    setDraft(text);
    requestAnimationFrame(() => textareaRef.current?.focus());
  };

  const regenerateLast = async () => {
    if (loading || !activeConversationId) return;
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

    try {
      if (!lastAssistant.tempId) {
        await deleteMessage(activeConversationId, lastAssistant.id);
      }
      setMessages((prev) => prev.filter((m) => m.id !== lastAssistant!.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to drop previous answer');
      return;
    }

    await sendQuery(lastUser.content, lastUser.mode);
  };

  const deleteFromMessage = async (id: string) => {
    if (!activeConversationId) return;
    const idx = messages.findIndex((m) => m.id === id);
    if (idx < 0) return;
    const target = messages.slice(idx);
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
          <span className="chat-title-text">Knowledge-Graph Chat</span>
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
            onClick={exportMarkdown}
            disabled={messages.length === 0}
            title="Export the conversation as Markdown"
          >
            ⬇ Export
          </button>
        </div>
      </header>

      <div className="chat-mode-row">
        <span>Mode</span>
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
        <span className="chat-mode-hint">{MODE_HINT[mode]}</span>
      </div>

      <div className="chat-thread" ref={threadRef}>
        {messages.length === 0 && !loading && !loadingMessages && (
          <div className="chat-empty">
            <p className="chat-empty-title">Ask the knowledge graph anything.</p>
            <p className="chat-empty-hint">
              Local is best for focused questions about a single concept; Global shines on cross-paper comparisons. Auto picks for you.
            </p>
            <div className="chat-suggestions">
              {suggestions.map((s) => (
                <button
                  key={s}
                  type="button"
                  className="chat-suggestion"
                  onClick={() => sendSuggestion(s)}
                  disabled={isBlocked || !isReady}
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
          const evOpen = openEvidence[m.id] ?? false;
          const isCopied = copiedId === m.id;
          const isLastAssistant =
            !isUser && idx === messages.length - 1 && m.role === 'assistant' && !m.pending;
          const isGlobalAnswer =
            m.role === 'assistant' &&
            (m.mode === 'global' || (m.mode === null && m.communities.length > 0));
          const evidenceCount =
            m.role === 'assistant'
              ? isGlobalAnswer ? m.communities.length : m.chunks.length
              : 0;
          const evidenceLabel =
            m.role === 'assistant'
              ? isGlobalAnswer
                ? `community contribution${m.communities.length === 1 ? '' : 's'}`
                : `chunk${m.chunks.length === 1 ? '' : 's'} from ${m.subgraphNodes.length} entit${m.subgraphNodes.length === 1 ? 'y' : 'ies'}`
              : '';
          return (
            <div className={`chat-row ${isUser ? 'is-user' : 'is-assistant'}`} key={m.id}>
              <div className="chat-row-meta">
                <span className="chat-role-tag">
                  {isUser ? `You · ${m.mode}` : 'Assistant'}
                </span>
                {!isUser && m.role === 'assistant' && m.mode && (
                  <span className="source-badge paper_profile">{m.mode} mode</span>
                )}
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

              {!isUser && !isPending && m.role === 'assistant' && (
                <>
                  {m.rewrittenQuery && (
                    <p className="chat-status" style={{ borderTop: 0, padding: '0.35rem 0.4rem', background: 'transparent' }}>
                      <em>Resolved follow-up to:</em> {m.rewrittenQuery}
                    </p>
                  )}
                  {!isGlobalAnswer && m.seeds.length > 0 && (
                    <div style={{ marginTop: '0.4rem' }}>
                      <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)', marginBottom: '0.3rem' }}>
                        Seed entities
                      </div>
                      <div className="community-entities">
                        {m.seeds.map((s) => (
                          <span className="entity-chip" key={s}>{s}</span>
                        ))}
                      </div>
                    </div>
                  )}
                  {isGlobalAnswer && m.candidateCount !== null && (
                    <p className="chat-status" style={{ borderTop: 0, padding: '0.35rem 0.4rem', background: 'transparent' }}>
                      Inspected {m.candidateCount} community candidate{m.candidateCount === 1 ? '' : 's'}; kept {m.communities.length}.
                    </p>
                  )}
                  {evidenceCount > 0 && (
                    <>
                      <button
                        className="chat-sources-chip"
                        onClick={() =>
                          setOpenEvidence((prev) => ({ ...prev, [m.id]: !prev[m.id] }))
                        }
                      >
                        {evOpen ? '▾' : '▸'} {evidenceLabel}
                        <span className="pill-count">{evidenceCount}</span>
                      </button>
                      {evOpen && (
                        <div className="chat-sources-panel sources-list">
                          {isGlobalAnswer && m.communities.map((c) => (
                            <div className="source-item" key={c.community_id}>
                              <div className="source-meta">
                                <span className="source-badge community">[Cm-{c.community_id}]</span>
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
                                  <ReactMarkdown
                                    remarkPlugins={markdownMathPlugins}
                                    rehypePlugins={[rehypeKatex]}
                                  >
                                    {normalizeMathMarkdown(c.contribution)}
                                  </ReactMarkdown>
                                </div>
                              )}
                              {c.papers && c.papers.length > 0 && (
                                <div style={{ marginTop: '0.4rem', fontSize: '0.72rem', color: 'var(--text-muted)' }}>
                                  Papers: {c.papers.join(', ')}
                                </div>
                              )}
                            </div>
                          ))}
                          {!isGlobalAnswer && m.chunks.map((s, i) => {
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
                      disabled={loading || isBlocked || !isReady}
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

      {!isReady && (
        <p className="chat-status">
          ⏳ Graph is not built yet. Go to the <strong>Graph</strong> tab to build it.
        </p>
      )}
      {isBlocked && isReady && !loading && (
        <p className="chat-status">
          ⏳ Query is temporarily disabled while another task is running.
        </p>
      )}
      {error && <p className="chat-status error">✗ {error}</p>}

      <form className="chat-composer" onSubmit={handleSubmit}>
        <div className="chat-textarea-wrap">
          <textarea
            ref={textareaRef}
            className="chat-textarea"
            placeholder={
              !isReady
                ? 'Build the graph first…'
                : isBlocked
                ? 'A task is running — please wait…'
                : mode === 'global'
                ? 'Ask a comparative or cross-paper question…'
                : 'Ask a focused question about an entity or concept…'
            }
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={isBlocked || !isReady}
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
            disabled={!draft.trim() || isBlocked || !isReady}
            title="Send (Enter)"
          >
            Send ▸
          </button>
        )}
      </form>
    </div>
  );
}
