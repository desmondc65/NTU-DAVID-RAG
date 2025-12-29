#!/usr/bin/env python3
"""
Fortran Parser for RAG Systems with Scope-Aware Context Extraction.

This parser handles monolithic Fortran programs with implicit scoping where
subroutines use global variables without passing them as arguments.

Key Features:
- Extracts global context (variables, parameters, declarations)
- Identifies subroutines and their variable dependencies
- Segments main logic into meaningful blocks (loops, I/O, allocations, sections)
- Creates scope-aware JSON output for LLM consumption
- Preserves variable definitions for proper context injection
"""

import argparse
import json
import re
from pathlib import Path
from typing import Dict, List, Tuple, Set


class FortranParser:
    """Parse Fortran source code with scope-aware context extraction."""
    
    def __init__(self, source_code: str, file_path: str):
        self.source_code = source_code
        self.file_path = file_path
        self.lines = source_code.split('\n')
        
    def parse(self) -> Dict:
        """
        Main parsing function that dissects Fortran code into structured components.
        
        Returns:
            Dictionary with global context and executable units
        """
        program_name = self._extract_program_name()
        global_context = self._extract_global_context()
        global_variables = self._extract_global_variables()
        subroutines = self._extract_subroutines(global_variables)
        main_logic = self._extract_main_logic()
        
        return {
            "file_path": self.file_path,
            "program_name": program_name,
            "global_context": global_context,
            "global_variables": global_variables,
            "main_logic": main_logic,
            "subroutines": subroutines,
            "metadata": {
                "total_lines": len(self.lines),
                "total_subroutines": len(subroutines),
                "total_global_vars": len(global_variables)
            }
        }
    
    def _extract_program_name(self) -> str:
        """Extract the program name from PROGRAM statement."""
        for line in self.lines:
            match = re.match(r'^\s*PROGRAM\s+(\w+)', line, re.IGNORECASE)
            if match:
                return match.group(1)
        return "unknown"
    
    def _extract_global_context(self) -> Dict:
        """
        Extract the global context (Category A): All declarations before CONTAINS.
        This includes PARAMETER, REAL, INTEGER, ALLOCATABLE, etc.
        """
        context_lines = []
        in_program = False
        contains_found = False
        start_line = 0
        end_line = 0
        
        for i, line in enumerate(self.lines):
            # Start collecting after PROGRAM statement
            if re.match(r'^\s*PROGRAM\s+', line, re.IGNORECASE):
                in_program = True
                start_line = i
                continue
            
            # Stop at CONTAINS
            if re.match(r'^\s*CONTAINS\s*$', line, re.IGNORECASE):
                contains_found = True
                end_line = i
                break
            
            # Stop at first executable statement (after declarations)
            if in_program and self._is_executable_statement(line):
                end_line = i
                break
            
            if in_program:
                context_lines.append(line)
        
        context_text = '\n'.join(context_lines)
        
        return {
            "text": context_text,
            "start_line": start_line + 1,
            "end_line": end_line,
            "line_count": len(context_lines)
        }
    
    def _extract_global_variables(self) -> List[Dict]:
        """
        Extract all global variable declarations with their types and values.
        This is critical for resolving implicit variable usage in subroutines.
        """
        variables = []
        in_program = False
        
        for i, line in enumerate(self.lines):
            if re.match(r'^\s*PROGRAM\s+', line, re.IGNORECASE):
                in_program = True
                continue
            
            if re.match(r'^\s*CONTAINS\s*$', line, re.IGNORECASE):
                break
            
            if not in_program:
                continue
            
            # Skip comments
            if re.match(r'^\s*!', line):
                continue
            
            # Match variable declarations
            var_info = self._parse_declaration_line(line, i)
            if var_info:
                variables.extend(var_info)
        
        return variables
    
    def _parse_declaration_line(self, line: str, line_num: int) -> List[Dict]:
        """Parse a single declaration line and extract variable information."""
        variables = []
        
        # Remove inline comments
        code_part = line.split('!')[0].strip()
        if not code_part:
            return variables
        
        # Match PARAMETER declarations
        param_match = re.match(
            r'^\s*(REAL|INTEGER|LOGICAL|CHARACTER)\s*(\([^)]+\))?\s*,\s*PARAMETER\s*::\s*(.+)',
            code_part, re.IGNORECASE
        )
        if param_match:
            var_type = param_match.group(1)
            type_spec = param_match.group(2) or ""
            declarations = param_match.group(3)
            
            # Parse multiple declarations
            for decl in declarations.split(','):
                decl = decl.strip()
                if '=' in decl:
                    var_name, value = decl.split('=', 1)
                    variables.append({
                        "name": var_name.strip(),
                        "type": f"{var_type}{type_spec}",
                        "category": "parameter",
                        "value": value.strip(),
                        "line": line_num + 1
                    })
        
        # Match regular variable declarations
        var_match = re.match(
            r'^\s*(REAL|INTEGER|LOGICAL|CHARACTER)\s*(\([^)]+\))?\s*::\s*(.+)',
            code_part, re.IGNORECASE
        )
        if var_match:
            var_type = var_match.group(1)
            type_spec = var_match.group(2) or ""
            declarations = var_match.group(3)
            
            for decl in declarations.split(','):
                decl = decl.strip()
                var_name = decl.split('=')[0].split('(')[0].strip()
                
                value = None
                if '=' in decl:
                    value = decl.split('=', 1)[1].strip()
                
                is_array = '(' in decl or 'DIMENSION' in line.upper()
                
                variables.append({
                    "name": var_name,
                    "type": f"{var_type}{type_spec}",
                    "category": "array" if is_array else "variable",
                    "value": value,
                    "line": line_num + 1
                })
        
        # Match ALLOCATABLE declarations
        alloc_match = re.match(
            r'^\s*(REAL|INTEGER|LOGICAL)\s*(\([^)]+\))?\s*,\s*ALLOCATABLE\s*::\s*(.+)',
            code_part, re.IGNORECASE
        )
        if alloc_match:
            var_type = alloc_match.group(1)
            type_spec = alloc_match.group(2) or ""
            declarations = alloc_match.group(3)
            
            for decl in declarations.split(','):
                decl = decl.strip()
                var_name = decl.split('(')[0].strip()
                variables.append({
                    "name": var_name,
                    "type": f"{var_type}{type_spec}",
                    "category": "allocatable",
                    "value": None,
                    "line": line_num + 1
                })
        
        return variables
    
    def _extract_subroutines(self, global_variables: List[Dict]) -> List[Dict]:
        """
        Extract all subroutines/functions with their dependencies on global variables.
        """
        subroutines = []
        in_contains = False
        current_sub = None
        sub_lines = []
        sub_start = 0
        
        global_var_names = {var['name'].upper() for var in global_variables}
        
        for i, line in enumerate(self.lines):
            # Detect CONTAINS section
            if re.match(r'^\s*CONTAINS\s*$', line, re.IGNORECASE):
                in_contains = True
                continue
            
            if not in_contains:
                continue
            
            # Detect subroutine start
            sub_match = re.match(
                r'^\s*(SUBROUTINE|FUNCTION)\s+(\w+)\s*(\([^)]*\))?',
                line, re.IGNORECASE
            )
            if sub_match:
                # Save previous subroutine if exists
                if current_sub:
                    sub_body = '\n'.join(sub_lines)
                    dependencies = self._find_variable_dependencies(
                        sub_body, global_var_names, current_sub['arguments']
                    )
                    current_sub['code'] = sub_body
                    current_sub['dependencies'] = dependencies
                    current_sub['end_line'] = i
                    subroutines.append(current_sub)
                
                # Start new subroutine
                sub_type = sub_match.group(1).upper()
                sub_name = sub_match.group(2)
                arguments = self._parse_arguments(sub_match.group(3) or "")
                
                current_sub = {
                    "name": sub_name,
                    "type": sub_type,
                    "arguments": arguments,
                    "start_line": i + 1
                }
                sub_lines = [line]
                sub_start = i
                continue
            
            # Detect subroutine end
            if current_sub and re.match(
                r'^\s*END\s+(SUBROUTINE|FUNCTION)\s+' + current_sub['name'],
                line, re.IGNORECASE
            ):
                sub_lines.append(line)
                sub_body = '\n'.join(sub_lines)
                dependencies = self._find_variable_dependencies(
                    sub_body, global_var_names, current_sub['arguments']
                )
                current_sub['code'] = sub_body
                current_sub['dependencies'] = dependencies
                current_sub['end_line'] = i + 1
                subroutines.append(current_sub)
                current_sub = None
                sub_lines = []
                continue
            
            if current_sub:
                sub_lines.append(line)
        
        # Handle last subroutine if not closed properly
        if current_sub and sub_lines:
            sub_body = '\n'.join(sub_lines)
            dependencies = self._find_variable_dependencies(
                sub_body, global_var_names, current_sub['arguments']
            )
            current_sub['code'] = sub_body
            current_sub['dependencies'] = dependencies
            current_sub['end_line'] = len(self.lines)
            subroutines.append(current_sub)
        
        return subroutines
    
    def _parse_arguments(self, arg_string: str) -> List[str]:
        """Parse subroutine/function arguments."""
        arg_string = arg_string.strip('()')
        if not arg_string:
            return []
        return [arg.strip() for arg in arg_string.split(',')]
    
    def _find_variable_dependencies(
        self, code: str, global_vars: Set[str], arguments: List[str]
    ) -> List[Dict]:
        """
        Find which global variables are used in the subroutine.
        This is the critical function for scope resolution.
        """
        dependencies = []
        arg_set = {arg.upper() for arg in arguments}
        
        # Find all variable usages (simple heuristic)
        # Match variable names (letters followed by letters/numbers/underscores)
        var_pattern = r'\b([a-zA-Z]\w*)\b'
        
        used_vars = set()
        for match in re.finditer(var_pattern, code):
            var_name = match.group(1).upper()
            used_vars.add(var_name)
        
        # Filter to only global variables that are not arguments
        for var in used_vars:
            if var in global_vars and var not in arg_set:
                dependencies.append({
                    "variable": var,
                    "type": "global_reference"
                })
        
        return dependencies
    
    def _extract_main_logic(self) -> Dict:
        """
        Extract the main execution logic between PROGRAM and CONTAINS.
        Also segments it into logical blocks based on comments and structure.
        """
        logic_lines = []
        in_program = False
        in_declarations = True
        start_line = 0
        end_line = 0
        
        for i, line in enumerate(self.lines):
            if re.match(r'^\s*PROGRAM\s+', line, re.IGNORECASE):
                in_program = True
                continue
            
            if re.match(r'^\s*CONTAINS\s*$', line, re.IGNORECASE):
                end_line = i
                break
            
            if in_program:
                # Detect when declarations end
                if in_declarations and self._is_executable_statement(line):
                    in_declarations = False
                    start_line = i
                
                if not in_declarations:
                    logic_lines.append((i, line))
        
        # Segment the logic into blocks
        logic_blocks = self._segment_logic_blocks(logic_lines, start_line)
        
        return {
            "text": '\n'.join([line for _, line in logic_lines]),
            "start_line": start_line + 1,
            "end_line": end_line,
            "line_count": len(logic_lines),
            "blocks": logic_blocks
        }
    
    def _segment_logic_blocks(self, logic_lines: List[Tuple[int, str]], offset: int) -> List[Dict]:
        """
        Segment main logic into meaningful blocks based on:
        - Comment headers (like !******)
        - ALLOCATE statements
        - DO loops
        - File I/O operations
        """
        blocks = []
        current_block = None
        current_block_lines = []
        
        for line_num, line in logic_lines:
            # Detect block headers (comment lines with asterisks)
            header_match = re.match(r'^\s*!\*+\s*$', line)
            if header_match:
                # Save previous block
                if current_block and current_block_lines:
                    current_block['code'] = '\n'.join(current_block_lines)
                    current_block['end_line'] = line_num
                    blocks.append(current_block)
                
                # Look ahead for the title
                current_block = {
                    "type": "section_header",
                    "start_line": line_num + 1
                }
                current_block_lines = []
                continue
            
            # Detect section title (comment after asterisks)
            if current_block and current_block.get("type") == "section_header" and line.strip().startswith('!'):
                title = line.strip().lstrip('!').strip()
                if title:
                    current_block["title"] = title
                    current_block["type"] = "logic_block"
                    current_block_lines = []
                continue
            
            # Detect ALLOCATE statements
            if re.match(r'^\s*ALLOCATE\s*\(', line, re.IGNORECASE):
                if not current_block or current_block.get("type") != "allocation":
                    if current_block and current_block_lines:
                        current_block['code'] = '\n'.join(current_block_lines)
                        current_block['end_line'] = line_num
                        blocks.append(current_block)
                    
                    current_block = {
                        "type": "allocation",
                        "title": "Memory Allocation",
                        "start_line": line_num + 1
                    }
                    current_block_lines = [line]
                else:
                    current_block_lines.append(line)
                continue
            
            # Detect major DO loops
            do_match = re.match(r'^\s*DO\s+(\w+)\s*=', line, re.IGNORECASE)
            if do_match:
                if current_block and current_block_lines:
                    current_block['code'] = '\n'.join(current_block_lines)
                    current_block['end_line'] = line_num
                    blocks.append(current_block)
                
                loop_var = do_match.group(1)
                current_block = {
                    "type": "loop",
                    "title": f"Loop over {loop_var}",
                    "loop_variable": loop_var,
                    "start_line": line_num + 1
                }
                current_block_lines = [line]
                continue
            
            # Detect file operations
            file_op_match = re.match(r'^\s*(OPEN|CLOSE|WRITE|READ)\s*\(', line, re.IGNORECASE)
            if file_op_match:
                if not current_block or current_block.get("type") != "file_io":
                    if current_block and current_block_lines:
                        current_block['code'] = '\n'.join(current_block_lines)
                        current_block['end_line'] = line_num
                        blocks.append(current_block)
                    
                    current_block = {
                        "type": "file_io",
                        "title": "File I/O Operations",
                        "start_line": line_num + 1
                    }
                    current_block_lines = [line]
                else:
                    current_block_lines.append(line)
                continue
            
            # Add to current block
            if current_block:
                current_block_lines.append(line)
        
        # Save last block
        if current_block and current_block_lines:
            current_block['code'] = '\n'.join(current_block_lines)
            current_block['end_line'] = logic_lines[-1][0] + 1
            blocks.append(current_block)
        
        return blocks
    
    def _is_executable_statement(self, line: str) -> bool:
        """Check if a line is an executable statement (not a declaration)."""
        code = line.split('!')[0].strip().upper()
        
        if not code or code.startswith('!'):
            return False
        
        # Declaration keywords
        declaration_keywords = [
            'REAL', 'INTEGER', 'LOGICAL', 'CHARACTER', 'COMPLEX',
            'DIMENSION', 'ALLOCATABLE', 'PARAMETER', 'IMPLICIT',
            'USE', 'INCLUDE', 'DATA'
        ]
        
        for keyword in declaration_keywords:
            if code.startswith(keyword):
                return False
        
        # Executable keywords
        executable_keywords = [
            'DO ', 'IF ', 'CALL ', 'RETURN', 'STOP', 'PRINT',
            'WRITE', 'READ', 'OPEN', 'CLOSE', 'ALLOCATE', 'DEALLOCATE',
            'WHERE', 'FORALL'
        ]
        
        for keyword in executable_keywords:
            if code.startswith(keyword):
                return True
        
        # Assignment statements (contains =)
        if '=' in code and '::' not in code:
            return True
        
        return False


def parse_fortran_file(file_path: str, output_dir: str = None):
    """
    Parse a Fortran file and generate scope-aware JSON output for RAG systems.
    
    Args:
        file_path: Path to the Fortran source file
        output_dir: Directory to save JSON output (optional)
    
    Returns:
        Parsed data dictionary
    """
    file_path = Path(file_path)
    
    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")
    
    # Read source code
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        source_code = f.read()
    
    # Parse
    parser = FortranParser(source_code, str(file_path))
    parsed_data = parser.parse()
    
    # Add enhanced metadata for RAG
    parsed_data['rag_metadata'] = {
        "description": "Fortran program with implicit scoping - subroutines use global variables",
        "usage_note": "When retrieving subroutines, always include global_context for variable definitions",
        "critical_dependencies": True
    }
    
    # Save to JSON if output directory specified
    if output_dir:
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        output_file = output_dir / f"{file_path.stem}_parsed.json"
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(parsed_data, f, indent=2, ensure_ascii=False)
        
        print(f"Parsed data saved to: {output_file}")
        
        # Also create a summary file
        summary_file = output_dir / f"{file_path.stem}_summary.txt"
        with open(summary_file, 'w', encoding='utf-8') as f:
            f.write(f"Fortran File Analysis Summary\n")
            f.write(f"{'='*60}\n\n")
            f.write(f"File: {file_path}\n")
            f.write(f"Program: {parsed_data['program_name']}\n\n")
            f.write(f"Global Variables: {parsed_data['metadata']['total_global_vars']}\n")
            f.write(f"Subroutines: {parsed_data['metadata']['total_subroutines']}\n")
            f.write(f"Total Lines: {parsed_data['metadata']['total_lines']}\n\n")
            
            # Main logic blocks
            if 'blocks' in parsed_data['main_logic']:
                f.write("Main Logic Blocks:\n")
                f.write("-" * 60 + "\n")
                for block in parsed_data['main_logic']['blocks']:
                    f.write(f"\n{block['type'].upper()}: {block.get('title', 'Unnamed')}\n")
                    f.write(f"  Lines: {block['start_line']}-{block.get('end_line', '?')}\n")
                    if 'loop_variable' in block:
                        f.write(f"  Loop Variable: {block['loop_variable']}\n")
                f.write("\n")
            
            f.write("Subroutines with Dependencies:\n")
            f.write("-" * 60 + "\n")
            for sub in parsed_data['subroutines']:
                f.write(f"\n{sub['name']} ({sub['type']})\n")
                f.write(f"  Lines: {sub['start_line']}-{sub['end_line']}\n")
                f.write(f"  Arguments: {', '.join(sub['arguments']) or 'None'}\n")
                if sub['dependencies']:
                    f.write(f"  Global Dependencies: {', '.join([d['variable'] for d in sub['dependencies']])}\n")
                else:
                    f.write(f"  Global Dependencies: None\n")
        
        print(f"Summary saved to: {summary_file}")
    
    return parsed_data


def process_directory(directory: str, output_dir: str = None):
    """
    Process all Fortran files in a directory.
    
    Args:
        directory: Path to directory containing Fortran files
        output_dir: Output directory for JSON files
    """
    directory = Path(directory)
    
    if not directory.exists():
        raise FileNotFoundError(f"Directory not found: {directory}")
    
    if not directory.is_dir():
        raise NotADirectoryError(f"Not a directory: {directory}")
    
    # Find all Fortran files
    fortran_extensions = {'.f90', '.f', '.f95', '.f03', '.for'}
    fortran_files = [
        f for f in directory.rglob('*') 
        if f.is_file() and f.suffix.lower() in fortran_extensions
    ]
    
    if not fortran_files:
        print(f"No Fortran files found in {directory}")
        return []
    
    print(f"\nFound {len(fortran_files)} Fortran file(s) in {directory}")
    print("="*60)
    
    results = []
    for i, file_path in enumerate(fortran_files, 1):
        print(f"\n[{i}/{len(fortran_files)}] Processing: {file_path.name}")
        print("-"*60)
        
        try:
            parsed_data = parse_fortran_file(str(file_path), output_dir)
            results.append({
                'file': str(file_path),
                'success': True,
                'data': parsed_data
            })
        except Exception as e:
            print(f"Error processing {file_path.name}: {e}")
            results.append({
                'file': str(file_path),
                'success': False,
                'error': str(e)
            })
    
    # Print summary
    print("\n" + "="*60)
    print("Processing Summary")
    print("="*60)
    successful = sum(1 for r in results if r['success'])
    failed = len(results) - successful
    print(f"Total files: {len(results)}")
    print(f"Successful: {successful}")
    print(f"Failed: {failed}")
    
    if failed > 0:
        print("\nFailed files:")
        for r in results:
            if not r['success']:
                print(f"  - {Path(r['file']).name}: {r['error']}")
    
    return results


def main():
    """Main CLI interface."""
    parser = argparse.ArgumentParser(
        description='Parse Fortran files with scope-aware context extraction for RAG systems.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Parse single file
  python fortran_parser.py main.f90
  python fortran_parser.py main.f90 -o output/
  
  # Parse all Fortran files in directory
  python fortran_parser.py codes_fortran/ -o parsed_fortran/
  python fortran_parser.py benchmark/ -o output/
  
This parser handles monolithic Fortran programs where subroutines use
global variables without explicit parameter passing. The output JSON
contains scope-aware context needed for LLM comprehension.
        '''
    )
    
    parser.add_argument(
        'path',
        type=str,
        help='Path to Fortran source file or directory containing Fortran files'
    )
    
    parser.add_argument(
        '-o', '--output',
        type=str,
        default=None,
        help='Output directory for JSON and summary files'
    )
    
    args = parser.parse_args()
    
    try:
        input_path = Path(args.path)
        
        if not input_path.exists():
            print(f"Error: Path does not exist: {input_path}")
            return 1
        
        # Check if input is a directory or file
        if input_path.is_dir():
            process_directory(str(input_path), args.output)
        else:
            parsed_data = parse_fortran_file(args.path, args.output)
            
            print("\n" + "="*60)
            print("Parsing Complete!")
            print("="*60)
            print(f"Program Name: {parsed_data['program_name']}")
            print(f"Global Variables: {parsed_data['metadata']['total_global_vars']}")
            print(f"Subroutines: {parsed_data['metadata']['total_subroutines']}")
            print(f"Total Lines: {parsed_data['metadata']['total_lines']}")
        
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
