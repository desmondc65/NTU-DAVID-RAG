import json
import re
import logging
from pathlib import Path
from typing import List, Optional, Union
from pydantic import BaseModel, Field

from utils.llm_clients.local_llm import LocalLLMClient

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RAGFortranFunction(BaseModel):
    """
    Schema representing a single extracted Fortran function tailored for RAG indexing.
    """
    function_name: str = Field(
        description="Name of the Fortran function, subroutine, or module."
    )
    purpose: str = Field(
        description="A clear, concise description of what the function does and its role."
    )
    pseudocode: str = Field(
        description="A step-by-step pseudocode representing the core logic and algorithm."
    )
    dependencies: List[str] = Field(
        default_factory=list,
        description="Other functions, external routines, or modules called within this function."
    )
    key_variables: List[str] = Field(
        default_factory=list,
        description="Important variables, common blocks, or arrays manipulated by this function."
    )

class RAGFortranDigest(BaseModel):
    """
    The full digest containing multiple important Fortran functions.
    """
    key_functions: List[RAGFortranFunction] = Field(
        description="List of the most important key functions/subroutines extracted from the code."
    )

def digest_fortran_code(
    code_content: str, 
    output_json_path: str, 
    model_name: str = "qwen2.5-vl-72b-instruct",
    base_url: str = "http://localhost:8000/v1",
    api_key: str = "local-dev-key"
) -> dict:
    """
    Accepts a very long Fortran code as a string, uses a local LLM to digest it, 
    extracts pseudocodes and metadata for important key functions only, 
    and saves them in a JSON file formatted optimally for a RAG indexing pipeline.

    Args:
        code_content (str): The raw Fortran code to be analyzed.
        output_json_path (str): The file path where the resulting JSON digest should be saved.
        model_name (str): The name of the LLM model to use.
        base_url (str): The base URL for the local LLM endpoint.
        api_key (str): The API key for the local LLM endpoint.

    Returns:
        dict: The digested key functions metadata as a dictionary.
    """
    logger.info(f"Initializing LocalLLMClient with model: {model_name}")
    client = LocalLLMClient(
        model_name=model_name,
        base_url=base_url,
        api_key=api_key,
    )
    
    system_prompt = (
        "You are an expert Fortran programmer and software architect. "
        "Your task is to analyze the provided Fortran code and extract the most critical functions, "
        "subroutines, or logical blocks. "
        "For each key function, you must extract its name, its core purpose, step-by-step pseudocode, "
        "its dependencies (what else it calls), and its key variables. "
        "Your output must be structured as a JSON document containing a list of these key functions to be used "
        "by a RAG (Retrieval-Augmented Generation) system for code search and understanding. "
        "CRITICAL INSTRUCTION: DO NOT OUTPUT ANY CONVERSATIONAL TEXT. STRICTLY OUTPUT ONLY THE JSON BLOCK."
    )
    
    # Prefixing code with line numbers helps the LLM with context, though not strictly necessary here.
    logger.info(f"Preparing to send prompt to the LLM. Total code length: {len(code_content)} characters.")
    
    # Chunk the code to prevent exceeding context window (65536 tokens ~ 150k chars depending on tokenization)
    max_chunk_chars = 80000
    overlap_chars = 15000  # Allow roughly ~15k chars of overlap between chunks
    
    lines = code_content.splitlines(keepends=True)
    chunks = []
    current_chunk_lines = []
    current_length = 0
    
    for line in lines:
        if current_length + len(line) > max_chunk_chars and current_length > 0:
            # Save the current chunk
            chunks.append("".join(current_chunk_lines))
            
            # Form next chunk's starting lines by backtracking for the overlap
            overlap_length = 0
            overlap_lines = []
            for prev_line in reversed(current_chunk_lines):
                if overlap_length + len(prev_line) > overlap_chars:
                    break
                overlap_lines.insert(0, prev_line)
                overlap_length += len(prev_line)
                
            current_chunk_lines = overlap_lines
            current_chunk_lines.append(line)
            current_length = overlap_length + len(line)
        else:
            current_chunk_lines.append(line)
            current_length += len(line)
            
    if current_chunk_lines:
        chunks.append("".join(current_chunk_lines))
        
    logger.info(f"Split code into {len(chunks)} chunks.")
    
    all_digests = []
    
    try:
        for i, chunk in enumerate(chunks):
            logger.info(f"Processing chunk {i+1}/{len(chunks)} (Length: {len(chunk)} chars)...")
            user_prompt_chunk = (
                "Please analyze the following Fortran code and output the key functions and their pseudocodes.\n"
                "Focus ONLY on the most important functional blocks.\n\n"
                f"```fortran\n{chunk}\n```\n"
            )
            raw_response = client.generate_response(
                user_prompt=user_prompt_chunk,
                system_prompt=system_prompt,
                response_mime_type="text/plain",
                max_tokens=8192,
                temperature=0.1
            )
            
            cleaned_response = raw_response.strip()
            
            # Robust JSON extraction using regex to ignore any surrounding conversational text
            json_match = re.search(r"```(?:json)?\s*(.*?)\s*```", cleaned_response, re.DOTALL | re.IGNORECASE)
            if json_match:
                cleaned_response = json_match.group(1).strip()
            else:
                if cleaned_response.startswith("```json"):
                    cleaned_response = cleaned_response[7:]
                if cleaned_response.startswith("```"):
                    cleaned_response = cleaned_response[3:]
                if cleaned_response.endswith("```"):
                    cleaned_response = cleaned_response[:-3]
                
            try:
                # Provide a fallback if json decoding fails
                chunk_dict = json.loads(cleaned_response.strip())
                if isinstance(chunk_dict, list):
                    all_digests.extend(chunk_dict)
                elif isinstance(chunk_dict, dict) and 'key_functions' in chunk_dict:
                    all_digests.extend(chunk_dict['key_functions'])
                elif isinstance(chunk_dict, dict):
                    all_digests.append(chunk_dict)
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON for chunk {i+1}: {e}")
                logger.error(f"Raw Response snippet: {raw_response[:200]}")
                continue
                
        # Final combined dictionary
        digest_dict = {"key_functions": all_digests}
        
        # Save to the desired JSON path
        output_path = Path(output_json_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(digest_dict, f, indent=4, ensure_ascii=False)
            
        logger.info(f"Successfully saved digested Fortran code pseudocodes to {output_json_path}")
        return digest_dict

    except Exception as e:
        logger.error(f"Error while digesting Fortran code: {e}")
        raise

def summarize_fortran_digest(
    json_path: Union[str, Path],
    model_name: str = "qwen2.5-vl-72b-instruct",
    base_url: str = "http://localhost:8000/v1",
    api_key: str = "local-dev-key"
):
    """
    Reads the digest JSON generated by digest_fortran_code, filters out duplicate 
    functions by name, uses an LLM to generate a summary index of all unique functions, 
    and saves the modifications back to the JSON file to be used as an index for RAG.
    """
    json_path = Path(json_path)
    if not json_path.exists():
        raise FileNotFoundError(f"JSON file not found: {json_path}")
        
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    logger.info("Filtering duplicate functions by name...")
    
    unique_functions = {}
    key_functions = data.get("key_functions", [])
    
    for func in key_functions:
        func_name = (func.get("function_name") or func.get("name") or "").strip().lower()
        if func_name and func_name not in unique_functions:
            unique_functions[func_name] = func
            
    filtered_functions = list(unique_functions.values())
    
    logger.info(f"Filtered down from {len(key_functions)} to {len(filtered_functions)} unique functions.")
    
    data["key_functions"] = filtered_functions
    
    logger.info("Initializing client for summary generation...")
    client = None
    modified = False
    
    for i, func in enumerate(filtered_functions):
        if "summary_index" in func and func["summary_index"]:
            func_name = func.get("function_name") or func.get("name") or "Unknown"
            logger.info(f"Skipping {func_name}, already summarized.")
            continue
            
        if client is None:
            try:
                client = LocalLLMClient(
                    model_name=model_name,
                    base_url=base_url,
                    api_key=api_key,
                )
            except Exception as e:
                logger.error(f"Error initializing LLM client: {e}")
                break
                
        func_name = func.get("function_name") or func.get("name") or "Unknown"
        purpose = func.get("purpose") or func.get("core_purpose") or ""
        pseudocode = func.get("pseudocode", "")
        if isinstance(pseudocode, list):
            pseudocode = "\n".join(pseudocode)
        key_variables = func.get("key_variables", [])
        
        user_prompt = (
            f"Task: Generate a search index summary for the Fortran function '{func_name}'. "
            "Keep it short and simple. Provide:\n"
            "1. Core Capability: (What operation does this function perform?)\n"
            "2. Algorithms/Logic: (Key steps it takes)\n"
            "3. Key Variables: (Important data structures manipulated)\n"
            "4. Keywords: (Comma-separated list of core terms for search indexing)\n\n"
            f"Purpose: {purpose}\n"
            f"Pseudocode:\n{pseudocode}\n"
            f"Key Variables: {key_variables}\n"
        )
        
        logger.info(f"Generating summary index for function {i+1}/{len(filtered_functions)}: {func_name}")
        try:
            response = client.generate_response(
                user_prompt=user_prompt,
                system_prompt="You are an expert code extraction system. Your output is used directly for dense vector retrieval of Fortran codebases. Focus on the algorithmic capabilities and terminology. Do not use conversational filler.",
                response_mime_type="text/plain",
                max_tokens=2048
            )
            func["summary_index"] = response.strip()
            modified = True
            
            # Intermittent save
            if (i + 1) % 5 == 0:
                with open(json_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=4, ensure_ascii=False)
                    
        except Exception as e:
            logger.error(f"Error generating summary index for {func_name}: {e}")
            
    if "summary_index" in data:
        # Delete the old top-level summary_index
        del data["summary_index"]
        modified = True
        
    if modified:
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
        logger.info(f"Finished updating {json_path} with per-function summaries.")
    else:
        logger.info("No new functions were summarized.")


if __name__ == "__main__":
    # Example usage (for testing)
    sample_fortran_code = """
    PROGRAM MAIN
      REAL A, B, C
      A = 10.0
      B = 20.0
      CALL ADD_NUMS(A, B, C)
      PRINT *, "The result is: ", C
    END PROGRAM MAIN

    SUBROUTINE ADD_NUMS(X, Y, Z)
      REAL X, Y, Z
      Z = X + Y
    END SUBROUTINE ADD_NUMS
    
    SUBROUTINE ADD_NUMS(X, Y, Z)
      REAL X, Y, Z
      Z = X + Y
    END SUBROUTINE ADD_NUMS
    """
    
    test_output_path = "output_test/fortran_digest.json"
    digest_fortran_code(
        code_content=sample_fortran_code, 
        output_json_path=test_output_path
    )
    summarize_fortran_digest(test_output_path)
