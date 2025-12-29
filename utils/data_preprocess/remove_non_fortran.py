#!/usr/bin/env python3
"""
Script to recursively find and filter Fortran files in a directory.
Keeps only files with standard Fortran extensions: .f, .f90, .f95, .f03, .for
Copies all found files to an output directory (flattened, no subdirectories).
"""

import argparse
import shutil
from pathlib import Path


def find_fortran_files(directory_path):
    """
    Recursively find all Fortran files in the given directory.
    
    Args:
        directory_path (Path): The directory to search
        
    Returns:
        list: List of Path objects for valid Fortran files
    """
    # Define valid Fortran extensions
    fortran_extensions = {'.f', '.f90', '.f95', '.f03', '.for'}
    
    # Find all files recursively
    all_files = directory_path.rglob('*')
    
    # Filter to keep only files (not directories) with Fortran extensions
    fortran_files = [
        file for file in all_files 
        if file.is_file() and file.suffix.lower() in fortran_extensions
    ]
    
    return fortran_files


def copy_files(fortran_files, source_dir, output_dir):
    """
    Copy Fortran files to the output directory (flattened structure).
    
    Args:
        fortran_files (list): List of Path objects for Fortran files
        source_dir (Path): The original search directory
        output_dir (Path): Directory path where files will be copied
    """
    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)
    
    copied_count = 0
    skipped_count = 0
    
    for file_path in fortran_files:
        try:
            # Use just the filename (no subdirectories)
            dest_path = output_dir / file_path.name
            
            # Handle filename conflicts
            if dest_path.exists():
                print(f"Warning: File already exists, skipping: {file_path.name}")
                skipped_count += 1
                continue
            
            # Copy the file
            shutil.copy2(str(file_path), str(dest_path))
            copied_count += 1
            
        except Exception as e:
            print(f"Error copying {file_path}: {e}")
            skipped_count += 1
    
    print(f"\nSuccessfully copied {copied_count} file(s) to: {output_dir.absolute()}")
    if skipped_count > 0:
        print(f"Skipped {skipped_count} file(s) due to conflicts or errors")


def main():
    """Main function to run the script."""
    # Set up argument parser
    parser = argparse.ArgumentParser(
        description='Recursively find all Fortran files in a directory.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  python remove_non_fortran.py /path/to/directory
  python remove_non_fortran.py /path/to/directory -o /path/to/output/dir
        '''
    )
    
    parser.add_argument(
        'directory',
        type=str,
        help='Directory path to search for Fortran files'
    )
    
    parser.add_argument(
        '-o', '--output',
        type=str,
        default=None,
        help='Optional output directory path to copy Fortran files (flattened, no subdirectories)'
    )
    
    args = parser.parse_args()
    
    # Convert to Path object
    directory = Path(args.directory)
    
    # Verify directory exists
    if not directory.exists():
        print(f"Error: The directory '{directory}' does not exist.")
        return
    
    if not directory.is_dir():
        print(f"Error: '{directory}' is not a directory.")
        return
    
    print(f"\nSearching for Fortran files in: {directory.absolute()}")
    print("-" * 60)
    
    # Find all Fortran files
    fortran_files = find_fortran_files(directory)
    
    # Output results
    if fortran_files:
        print(f"\nFound {len(fortran_files)} Fortran file(s)")
        
        if args.output:
            # Copy files to output directory
            output_dir = Path(args.output)
            copy_files(fortran_files, directory, output_dir)
        else:
            # Print to console
            print()
            for file_path in sorted(fortran_files):
                print(file_path)
    else:
        print("\nNo Fortran files found in the specified directory.")


if __name__ == "__main__":
    main()
