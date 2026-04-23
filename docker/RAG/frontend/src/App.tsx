import { useState } from 'react';
import ManagePapers from './components/ManagePapers';
import ChatPage from './components/ChatPage';
import { AuthProvider, useAuth } from './auth/AuthContext';
import LoginPage from './auth/LoginPage';

type Tab = 'manage' | 'query';

function AppShell() {
  const { user, loading, logout } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>('manage');
  const [isIngesting, setIsIngesting] = useState(false);

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
          id="tab-manage"
          className={`tab-btn ${activeTab === 'manage' ? 'active' : ''}`}
          onClick={() => setActiveTab('manage')}
        >
          📄 Manage Papers
        </button>
        <button
          id="tab-query"
          className={`tab-btn ${activeTab === 'query' ? 'active' : ''}`}
          onClick={() => setActiveTab('query')}
        >
          🔍 RAG Query
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
          <ManagePapers onProcessingChange={setIsIngesting} />
        </section>
        <section className={`tab-panel ${activeTab === 'query' ? '' : 'hidden'}`}>
          <ChatPage isBlocked={isIngesting} />
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
