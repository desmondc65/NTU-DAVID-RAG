import { useEffect, useState } from 'react';
import type { ConversationSummary } from '../api';
import {
  createConversation,
  deleteConversation,
  fetchConversations,
  renameConversation,
} from '../api';

type Props = {
  activeId: string | null;
  onSelect: (id: string | null) => void;
  /** Bumped by the query flow whenever a new conversation is created or an
      existing one gets a new message, so the sidebar can refetch. */
  refreshToken: number;
  onAfterRefresh?: (list: ConversationSummary[]) => void;
  onCollapse?: () => void;
};

function relTime(iso: string | null): string {
  if (!iso) return '';
  const t = new Date(iso).getTime();
  if (!Number.isFinite(t)) return '';
  const diff = Date.now() - t;
  const s = Math.floor(diff / 1000);
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d}d ago`;
  return new Date(iso).toLocaleDateString();
}

export default function ConversationSidebar({
  activeId,
  onSelect,
  refreshToken,
  onAfterRefresh,
  onCollapse,
}: Props) {
  const [items, setItems] = useState<ConversationSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValue, setEditValue] = useState('');

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const list = await fetchConversations();
      setItems(list);
      onAfterRefresh?.(list);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load conversations');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refreshToken]);

  const handleNew = async () => {
    try {
      const conv = await createConversation();
      setItems((prev) => [conv, ...prev.filter((c) => c.id !== conv.id)]);
      onSelect(conv.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create conversation');
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Delete this conversation? It will be hidden from your history.')) return;
    try {
      await deleteConversation(id);
      setItems((prev) => prev.filter((c) => c.id !== id));
      if (activeId === id) {
        onSelect(null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Delete failed');
    }
  };

  const startRename = (conv: ConversationSummary) => {
    setEditingId(conv.id);
    setEditValue(conv.title);
  };

  const commitRename = async () => {
    if (!editingId) return;
    const title = editValue.trim();
    if (!title) { setEditingId(null); return; }
    try {
      const updated = await renameConversation(editingId, title);
      setItems((prev) => prev.map((c) => (c.id === updated.id ? { ...c, title: updated.title } : c)));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Rename failed');
    } finally {
      setEditingId(null);
    }
  };

  return (
    <aside className="conv-sidebar">
      <div className="conv-sidebar-header">
        <button type="button" className="conv-new-btn" onClick={handleNew}>
          ＋ New chat
        </button>
        {onCollapse && (
          <button
            type="button"
            className="conv-collapse-btn"
            title="Hide history"
            onClick={onCollapse}
          >
            ⟨
          </button>
        )}
      </div>
      {error && <p className="conv-error">{error}</p>}
      {loading && items.length === 0 && <p className="conv-empty">Loading…</p>}
      {!loading && items.length === 0 && !error && (
        <p className="conv-empty">No conversations yet.</p>
      )}
      <ul className="conv-list">
        {items.map((c) => {
          const isActive = c.id === activeId;
          const isEditing = editingId === c.id;
          return (
            <li key={c.id} className={`conv-item ${isActive ? 'is-active' : ''}`}>
              {isEditing ? (
                <input
                  className="conv-rename-input"
                  value={editValue}
                  autoFocus
                  onChange={(e) => setEditValue(e.target.value)}
                  onBlur={() => void commitRename()}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') { e.preventDefault(); void commitRename(); }
                    if (e.key === 'Escape') { setEditingId(null); }
                  }}
                />
              ) : (
                <button
                  type="button"
                  className="conv-select"
                  onClick={() => onSelect(c.id)}
                  title={c.title}
                >
                  <div className="conv-title">{c.title}</div>
                  <div className="conv-meta">
                    {c.message_count} msg{c.message_count === 1 ? '' : 's'}
                    <span className="conv-sep">·</span>
                    {relTime(c.last_message_at || c.updated_at)}
                  </div>
                </button>
              )}
              {!isEditing && (
                <div className="conv-item-actions">
                  <button
                    type="button"
                    className="conv-icon-btn"
                    title="Rename"
                    onClick={() => startRename(c)}
                  >
                    ✎
                  </button>
                  <button
                    type="button"
                    className="conv-icon-btn danger"
                    title="Delete conversation"
                    onClick={() => void handleDelete(c.id)}
                  >
                    ✕
                  </button>
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </aside>
  );
}
