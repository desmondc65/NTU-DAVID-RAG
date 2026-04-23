import { useState } from 'react';
import ManagePapers from './components/ManagePapers';
import ChatPage from './components/ChatPage';
import { AuthProvider, useAuth } from './auth/AuthContext';
import LoginPage from './auth/LoginPage';
import AccountDialog from './auth/AccountDialog';

type Tab = 'manage' | 'query';

function switchService(target: 'rag' | 'graph') {
  try {
    if (window.top && window.top !== window.self) {
      (window.top as Window).location.hash = '#' + target;
      return;
    }
  } catch {
    /* cross-origin access blocked — fall through to full nav */
  }
  window.location.href = '/' + target + '/';
}

function AppShell() {
  const { user, loading, logout } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>('query');
  const [isIngesting, setIsIngesting] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);

  if (loading) {
    return <div className="auth-loading">Loading…</div>;
  }
  if (!user) {
    return <LoginPage />;
  }

  return (
    <div className="app">
      <nav className="topbar">
        <span className="brand">NTU DAVID RAG</span>
        <div className="service-switch">
          <button
            type="button"
            className="service-btn active"
            onClick={() => switchService('rag')}
          >
            RAG
          </button>
          <button
            type="button"
            className="service-btn"
            onClick={() => switchService('graph')}
          >
            GraphRAG
          </button>
        </div>
        <span className="topbar-divider" />
        <div className="app-tabs">
          <button
            id="tab-manage"
            className={`tab-btn ${activeTab === 'manage' ? 'active' : ''}`}
            onClick={() => setActiveTab('manage')}
          >
            Manage Papers
          </button>
          <button
            id="tab-query"
            className={`tab-btn ${activeTab === 'query' ? 'active' : ''}`}
            onClick={() => setActiveTab('query')}
          >
            Query
          </button>
        </div>
        <div className="tabs-spacer" />
        <button
          type="button"
          className="auth-badge auth-badge-btn"
          title={`Account — ${user.email}`}
          onClick={() => setAccountOpen(true)}
        >
          {user.display_name || user.email}
        </button>
        <button
          className="tab-btn auth-logout"
          onClick={() => { void logout(); }}
        >
          Sign out
        </button>
      </nav>

      <main className={`tab-content ${activeTab === 'query' ? 'tab-content-full' : ''}`}>
        <section className={`tab-panel ${activeTab === 'manage' ? '' : 'hidden'}`}>
          <ManagePapers onProcessingChange={setIsIngesting} />
        </section>
        <section className={`tab-panel ${activeTab === 'query' ? '' : 'hidden'}`}>
          <ChatPage isBlocked={isIngesting} />
        </section>
      </main>

      <AccountDialog open={accountOpen} onClose={() => setAccountOpen(false)} />
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
