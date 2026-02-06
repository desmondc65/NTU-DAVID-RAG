import re
import hashlib
import json
import os
try:
    import tiktoken
except ImportError:
    tiktoken = None

class RAGChunker:
    def __init__(self, model_name="gpt-4"):
        self.model_name = model_name
        if tiktoken:
            try:
                self.tokenizer = tiktoken.encoding_for_model(model_name)
            except:
                self.tokenizer = tiktoken.get_encoding("cl100k_base")
        else:
            self.tokenizer = None

    def _count_tokens(self, text: str) -> int:
        if self.tokenizer:
            return len(self.tokenizer.encode(text))
        else:
            # Fallback approximation: 1 token ~= 4 chars
            return len(text) // 4

    def clean_manuscript(self, text: str) -> str:
        """
        Full pipeline to clean the Docling parsed markdown.
        """
        # --- STEP 1: SECTION PRUNING (Head & Tail) ---
        
        # 1. Truncate References (The Tail)
        ref_split = re.split(r'^##\s+REFERENCES', text, flags=re.MULTILINE | re.IGNORECASE)
        if len(ref_split) > 1:
            text = ref_split[0]
        
        # 2. Remove Author Affiliations (The Head)
        text = re.sub(r'^\*\s+Kaymak:.*?\†', '', text, flags=re.DOTALL | re.MULTILINE)
        
        # 3. Remove Journal Navigation Boilerplate
        text = re.sub(r'Go\s+to\s+https://doi\.org/.*?(statement|s)\s+\(\s+s\s+\)\s+\.', '', text, flags=re.IGNORECASE | re.DOTALL)
        
        # --- STEP 2: ARTIFACT REPAIR (The Regex Fixes) ---
        
        # 4. Fix Broken Unicode (Hex codes)
        def replace_uni(match):
            try:
                return chr(int(match.group(1), 16))
            except ValueError:
                return match.group(0)
                
        text = re.sub(r'/uni([0-9A-Fa-f]{4})', replace_uni, text)
        
        # 5. Fix "Spaced Diacritics" (The Docling Glitch)
        replacements = {
            r's\s?¸': 'ş',
            r'S\s?¸': 'Ş',
            r'u\s?¨': 'ü',
            r'U\s?¨': 'Ü',
            r'o\s?¨': 'ö',
            r'O\s?¨': 'Ö',
            r'g\s?˘': 'ğ',
            r'I\s?˙': 'İ',
        }
        for pat, repl in replacements.items():
            text = re.sub(pat, repl, text)

        # 6. Remove Running Headers (e.g., VOL. 18 NO. 1)
        text = re.sub(r'VOL\.\s+\d+\s+NO\.\s+\d+', '', text)

        # 7. Fix Hyphenated Line Breaks (De-hyphenation)
        text = re.sub(r'(\w+)-\s*\n\s*(\w+)', r'\1\2', text)
        
        return text.strip()

    def chunk_manuscript(self, text: str, source_id: str, file_path: str = None) -> list[dict]:
        """
        Hierarchical chunking strategy.
        Target Size: 512 tokens.
        Overlap: 50 tokens.
        """
        chunks = []
        
        # Step A: Section Segmentation
        # Split by Headers (## Title)
        # Using a regex that captures the delimiter to keep the title.
        # This splits into: [preamble, title1, content1, title2, content2, ...]
        parts = re.split(r'(^##\s+.*$)', text, flags=re.MULTILINE)
        
        current_section_title = "Introduction" # Default for preamble
        
        # If the file starts with content before any header
        if parts[0].strip():
             self._process_section_content(parts[0], current_section_title, source_id, file_path, chunks)

        # Iterate over title-content pairs
        for i in range(1, len(parts), 2):
            title_line = parts[i].strip()
            content_block = parts[i+1] if i + 1 < len(parts) else ""
            
            # Extract cleaner title (remove hashes)
            current_section_title = title_line.lstrip('#').strip()
            
            self._process_section_content(content_block, current_section_title, source_id, file_path, chunks)
            
        return chunks

    def _process_section_content(self, content: str, section_title: str, source_id: str, file_path: str, chunks_list: list):
        """
        Classifies content into Table vs Text and chunks accordingly.
        """
        lines = content.split('\n')
        current_block_type = None
        current_block_lines = []
        
        for line in lines:
            line_stripped = line.strip()
            if not line_stripped:
                continue
            
            # Check if line looks like a table row (starts with |)
            is_table_line = line_stripped.startswith('|')
            
            # Determine type
            line_type = 'table' if is_table_line else 'text'
            
            if line_type != current_block_type:
                # Type switch occurred, process accumulated block
                if current_block_type and current_block_lines:
                    self._create_chunks(current_block_lines, current_block_type, section_title, source_id, file_path, chunks_list)
                
                # Reset for new block
                current_block_type = line_type
                current_block_lines = [line]
            else:
                current_block_lines.append(line)
        
        # Process final block
        if current_block_type and current_block_lines:
             self._create_chunks(current_block_lines, current_block_type, section_title, source_id, file_path, chunks_list)

    def _create_chunks(self, lines: list, block_type: str, section_title: str, source_id: str, file_path: str, chunks_list: list):
        if block_type == 'table':
            # Atomic Chunk: Do not split tables
            content_text = '\n'.join(lines)
            self._add_chunk(content_text, section_title, 'table', source_id, file_path, chunks_list)
        else:
            # Text Chunking with Context Injection and sliding window
            full_text = '\n'.join(lines)
            
            # Sentence Splitting (Regex for . ? ! followed by space or end)
            # A positive lookbehind (?<=[.!?]) checks for punctuation, then splits on whitespace.
            sentences = re.split(r'(?<=[.!?])\s+', full_text)
            
            current_chunk_sentences = []
            current_token_count = 0
            
            TARGET_TOKENS = 512
            OVERLAP_TOKENS = 50
            
            # Context Prefix
            context_prefix = f"Section: {section_title}. Content: "
            prefix_tokens = self._count_tokens(context_prefix)
            
            i = 0
            while i < len(sentences):
                sentence = sentences[i]
                sent_tokens = self._count_tokens(sentence)
                
                # If adding this sentence exceeds target (and we have something), output chunk
                if current_token_count + sent_tokens + prefix_tokens > TARGET_TOKENS and current_chunk_sentences:
                    chunk_text = context_prefix + " ".join(current_chunk_sentences)
                    self._add_chunk(chunk_text, section_title, 'text', source_id, file_path, chunks_list)
                    
                    # Overlap Logic: Keep last sentences roughly equal to OVERLAP_TOKENS
                    overlap_buffer = []
                    overlap_count = 0
                    
                    # Simpler Overlap: Just take the last N sentences that fit in ~50 tokens
                    overlap_accum = []
                    overlap_accum_tokens = 0
                    for s in reversed(current_chunk_sentences):
                        t = self._count_tokens(s)
                        if overlap_accum_tokens + t <= OVERLAP_TOKENS:
                            overlap_accum.insert(0, s)
                            overlap_accum_tokens += t
                        else:
                            break
                    
                    current_chunk_sentences = overlap_accum
                    current_token_count = overlap_accum_tokens
                    
                    # Do not increment i, we just processed up to i-1. Now we try adding sentence[i] again to the *new* current_chunk_sentences
                    # Loop continues...
                    # Check for huge sentence case again
                    if sent_tokens > TARGET_TOKENS:
                         # Force add huge sentence
                         current_chunk_sentences.append(sentence)
                         chunk_text = context_prefix + " ".join(current_chunk_sentences)
                         self._add_chunk(chunk_text, section_title, 'text', source_id, file_path, chunks_list)
                         current_chunk_sentences = []
                         current_token_count = 0
                         i += 1
                    else:
                         pass
                else:
                    current_chunk_sentences.append(sentence)
                    current_token_count += sent_tokens
                    i += 1
            
            # Flush remaining
            if current_chunk_sentences:
                chunk_text = context_prefix + " ".join(current_chunk_sentences)
                self._add_chunk(chunk_text, section_title, 'text', source_id, file_path, chunks_list)

    def _add_chunk(self, text: str, section_header: str, content_type: str, source: str, file_path: str, chunks_list: list):
        chunk_id = hashlib.md5(text.encode('utf-8')).hexdigest()
        metadata = {
            "source": source,
            "section_header": section_header,
            "content_type": content_type
        }
        if file_path:
            metadata["file_path"] = file_path
            
        chunks_list.append({
            "chunk_id": chunk_id,
            "text": text,
            "metadata": metadata
        })

    def process_file(self, input_path: str, output_path: str):
        if not os.path.exists(input_path):
             raise FileNotFoundError(f"Input file not found: {input_path}")
             
        with open(input_path, 'r', encoding='utf-8') as f:
            raw_text = f.read()
            
        cleaned_text = self.clean_manuscript(raw_text)
        
        filename = os.path.basename(input_path)
        abs_path = os.path.abspath(input_path)
        chunks = self.chunk_manuscript(cleaned_text, source_id=filename, file_path=abs_path)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            for chunk in chunks:
                f.write(json.dumps(chunk) + '\n')
                
        print(f"Processed {len(chunks)} chunks to {output_path}")

if __name__ == "__main__":
    # Example Usage
    import sys
    if len(sys.argv) > 2:
        c = RAGChunker()
        c.process_file(sys.argv[1], sys.argv[2])
