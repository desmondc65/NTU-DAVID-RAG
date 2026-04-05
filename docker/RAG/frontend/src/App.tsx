import { useState } from 'react';
import ManagePapers from './components/ManagePapers';
import QueryTab from './components/QueryTab';

type Tab = 'manage' | 'query';

export default function App() {
  const [activeTab, setActiveTab] = useState<Tab>('manage');
  const [isIngesting, setIsIngesting] = useState(false);

  return (
    <div className="app">
      <header className="app-header">
        <span className="app-logo">Econ-RAG</span>
        <span className="app-subtitle">Research Assistant</span>
      </header>

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
      </nav>

      <main className="tab-content">
        <section className={`tab-panel ${activeTab === 'manage' ? '' : 'hidden'}`}>
          <ManagePapers onProcessingChange={setIsIngesting} />
        </section>
        <section className={`tab-panel ${activeTab === 'query' ? '' : 'hidden'}`}>
          <QueryTab isBlocked={isIngesting} />
        </section>
      </main>
    </div>
  );
}
