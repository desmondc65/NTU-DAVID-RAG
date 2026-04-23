/** Types shared between frontend components and API responses. */

export interface Paper {
  paper_title: string;
  authors: string;
  ingest_date: string;
  content_list_path: string;
  fortran_digest_path: string;
}

export interface SourceItem {
  text: string;
  metadata: Record<string, string>;
  score: number;
}

export interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

export interface QueryResponse {
  answer: string;
  sources: SourceItem[];
  conversation_id?: string;
  message_ids?: {
    user: string;
    assistant: string;
  };
}

export interface UploadResponse {
  status: string;
  message: string;
  store_result?: {
    manuscript_chunks: number;
    fortran_chunks: number;
    total_in_db: number;
  };
  error?: string;
}

export interface StatusResponse {
  status: string;
  papers_count: number;
  db_path: string;
}
