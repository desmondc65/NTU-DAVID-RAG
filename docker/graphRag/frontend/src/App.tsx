import { useCallback, useEffect, useState } from 'react';
import ManagePapers from './components/ManagePapers';
import GraphTab from './components/GraphTab';
import ChatPage from './components/ChatPage';
import { fetchStatus } from './api';
import type { GraphStatus } from './types';
import { AuthProvider, useAuth } from './auth/AuthContext';
import LoginPage from './auth/LoginPage';

type Tab = 'manage' | 'graph' | 'query';

function AppShell() {
  const { user, loading, logout } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>('manage');
  const [isProcessing, setIsProcessing] = useState(false);
  const [status, setStatus] = useState<GraphStatus | null>(null);

  const refreshStatus = useCallback(async () => {
    try {
      setStatus(await fetchStatus());
    } catch {
      setStatus(null);
    }
  }, []);

  useEffect(() => {
    if (!user) return;
    refreshStatus();
  }, [refreshStatus, user]);

  if (loading) {
    return <div className="auth-loading">Loading…</div>;
  }
  if (!user) {
    return <LoginPage />;
  }

  return (
    <div className="app">
      <nav className="tabs">
        <button
          className={`tab-btn ${activeTab === 'manage' ? 'active' : ''}`}
          onClick={() => setActiveTab('manage')}
        >
          📄 Manage Papers
        </button>
        <button
          className={`tab-btn ${activeTab === 'graph' ? 'active' : ''}`}
          onClick={() => setActiveTab('graph')}
        >
          🕸 Graph
        </button>
        <button
          className={`tab-btn ${activeTab === 'query' ? 'active' : ''}`}
          onClick={() => setActiveTab('query')}
        >
          🔍 Query
        </button>
        <div className="tabs-spacer" />
        <span className="auth-badge" title={user.email}>
          {user.display_name || user.email}
        </span>
        <button
          className="tab-btn auth-logout"
          onClick={() => { void logout(); }}
        >
          Sign out
        </button>
      </nav>

      <main className="tab-content">
        <section className={`tab-panel ${activeTab === 'manage' ? '' : 'hidden'}`}>
          <ManagePapers
            onProcessingChange={setIsProcessing}
            onPapersChanged={refreshStatus}
          />
        </section>
        <section className={`tab-panel ${activeTab === 'graph' ? '' : 'hidden'}`}>
          <GraphTab
            status={status}
            isBlocked={isProcessing}
            onProcessingChange={setIsProcessing}
            onBuilt={refreshStatus}
          />
        </section>
        <section className={`tab-panel ${activeTab === 'query' ? '' : 'hidden'}`}>
          <ChatPage status={status} isBlocked={isProcessing} />
        </section>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <AppShell />
    </AuthProvider>
  );
}
