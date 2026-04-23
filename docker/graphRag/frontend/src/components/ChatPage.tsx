import { useCallback, useState } from 'react';
import ConversationSidebar from './ConversationSidebar';
import QueryTab from './QueryTab';
import type { GraphStatus } from '../types';

type Props = {
  status: GraphStatus | null;
  isBlocked: boolean;
};

export default function ChatPage({ status, isBlocked }: Props) {
  const [activeId, setActiveId] = useState<string | null>(null);
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
        status={status}
        isBlocked={isBlocked}
        activeConversationId={activeId}
        onConversationCreated={handleCreated}
        onConversationTouched={handleTouched}
      />
    </div>
  );
}
