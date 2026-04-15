import { useCallback, useEffect, useState } from 'react';
import ManagePapers from './components/ManagePapers';
import GraphTab from './components/GraphTab';
import QueryTab from './components/QueryTab';
import { fetchStatus } from './api';
import type { GraphStatus } from './types';

type Tab = 'manage' | 'graph' | 'query';

export default function App() {
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
    refreshStatus();
  }, [refreshStatus]);

  return (
    <div className="app">
      <header className="app-header">
        <span className="app-logo">Econ-GraphRAG</span>
        <span className="app-subtitle">Knowledge Graph Assistant</span>
      </header>

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
          <QueryTab status={status} isBlocked={isProcessing} />
        </section>
      </main>
    </div>
  );
}
