import re

class RAGChunker:
    def __init__(self):
        pass

    def clean_manuscript(self, text: str) -> str:
        """
        Full pipeline to clean the Docling parsed markdown.
        """
        # --- STEP 1: SECTION PRUNING (Head & Tail) ---
        
        # 1. Truncate References (The Tail)
        # Finds '## REFERENCES' and discards everything after it.
        # Flags: re.IGNORECASE to be safe, though Docling usually caps headers.
        ref_split = re.split(r'^##\s+REFERENCES', text, flags=re.MULTILINE | re.IGNORECASE)
        if len(ref_split) > 1:
            text = ref_split[0]
        
        # 2. Remove Author Affiliations (The Head)
        # Matches the block starting with "* Kaymak:" and ending with the dagger "†"
        # DOTALL allows the dot (.) to match newlines, capturing the whole block.
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
        # Compresses "Ays ¸ egu ¨l" -> "Ayşegül"
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
        # Joins "extra-\nordinary" -> "extraordinary"
        text = re.sub(r'(\w+)-\s*\n\s*(\w+)', r'\1\2', text)
        
        return text.strip()
