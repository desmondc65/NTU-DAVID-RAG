import { useCallback, useState } from 'react';
import ConversationSidebar from './ConversationSidebar';
import QueryTab from './QueryTab';

type Props = {
  isBlocked: boolean;
};

export default function ChatPage({ isBlocked }: Props) {
  const [activeId, setActiveId] = useState<string | null>(null);
  // Bumped when a query creates a new conversation or appends messages, so
  // the sidebar refetches to show up-to-date titles/timestamps/counts.
  const [sidebarRefresh, setSidebarRefresh] = useState(0);

  const handleCreated = useCallback((id: string) => {
    setActiveId(id);
    setSidebarRefresh((n) => n + 1);
  }, []);

  const handleTouched = useCallback(() => {
    setSidebarRefresh((n) => n + 1);
  }, []);

  return (
    <div className="chat-page">
      <ConversationSidebar
        activeId={activeId}
        onSelect={setActiveId}
        refreshToken={sidebarRefresh}
      />
      <QueryTab
        isBlocked={isBlocked}
        activeConversationId={activeId}
        onConversationCreated={handleCreated}
        onConversationTouched={handleTouched}
      />
    </div>
  );
}
