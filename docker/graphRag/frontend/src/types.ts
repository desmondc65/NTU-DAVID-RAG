/** Types shared between frontend components and GraphRAG API responses. */

export interface Paper {
  paper_title: string;
  authors: string;
  ingest_date: string;
  content_list_path?: string;
  fortran_digest_path?: string;
}

export interface UploadResponse {
  status: string;
  message: string;
  paper_dir?: string;
  store_result?: {
    manuscript_chunks: number;
    fortran_chunks: number;
    total_in_db: number;
  };
  error?: string;
}

export interface GraphStatus {
  service: string;
  db_path: string;
  built: boolean;
  built_at?: string;
  n_chunks?: number;
  n_nodes?: number;
  n_edges?: number;
  n_communities?: number;
  n_entities_raw?: number;
  n_relationships_raw?: number;
  paper_filter?: string[];
  skip_fortran?: boolean;
}

export interface BuildRequest {
  paper_filter?: string[] | null;
  skip_fortran?: boolean;
  max_chunks?: number | null;
}

export interface BuildResponse {
  status: string;
  stats: {
    n_chunks: number;
    n_nodes: number;
    n_edges: number;
    n_communities: number;
  };
}

export interface Community {
  community_id: number;
  title: string;
  theme: string;
  summary: string;
  key_entities: string[];
  paper_titles: string[];
  size: number;
}

export type QueryMode = 'auto' | 'local' | 'global';

export interface QueryRequest {
  query: string;
  mode?: QueryMode;
  n_hop?: number;
  max_chunks?: number;
  candidate_top_k?: number;
  keep_top_k?: number;
  max_generation_tokens?: number;
}

export interface ChunkSource {
  id: string;
  text: string;
  metadata: Record<string, string>;
}

export interface CommunityContribution {
  community_id: number;
  title: string;
  theme: string;
  score: number;
  contribution: string;
  papers: string[];
}

export interface QueryResponse {
  answer: string;
  mode: QueryMode;
  /** Local mode */
  seeds?: string[];
  subgraph_nodes?: string[];
  chunks?: ChunkSource[];
  /** Global mode */
  communities?: CommunityContribution[];
  candidate_count?: number;
}
