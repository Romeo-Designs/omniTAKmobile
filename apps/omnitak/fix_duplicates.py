#!/usr/bin/env python3
"""
Fix duplicate build file references in Xcode project
"""
import re
import shutil
from pathlib import Path

def fix_duplicate_build_files(project_path):
    """Remove duplicate file references from PBXSourcesBuildPhase"""

    # Backup the original file
    backup_path = project_path.with_suffix('.pbxproj.backup')
    if backup_path.exists():
        backup_path.unlink()
    shutil.copy2(project_path, backup_path)
    print(f"Created backup: {backup_path}")

    # Read the project file
    with open(project_path, 'r') as f:
        lines = f.readlines()

    # Process line by line to find and remove duplicates in PBXSourcesBuildPhase
    in_sources_phase = False
    seen_files = set()
    new_lines = []
    duplicates_removed = 0

    for line in lines:
        # Check if we're entering PBXSourcesBuildPhase
        if 'Begin PBXSourcesBuildPhase' in line:
            in_sources_phase = True
            new_lines.append(line)
            continue

        # Check if we're exiting PBXSourcesBuildPhase
        if 'End PBXSourcesBuildPhase' in line:
            in_sources_phase = False
            seen_files.clear()
            new_lines.append(line)
            continue

        # If we're in the sources phase and this is a file reference
        if in_sources_phase and ' in Sources */' in line:
            # Extract filename from comment
            filename_match = re.search(r'/\* (.+?) in Sources \*/', line)
            if filename_match:
                filename = filename_match.group(1)
                if filename not in seen_files:
                    seen_files.add(filename)
                    new_lines.append(line)
                else:
                    duplicates_removed += 1
                    print(f"  Removing duplicate: {filename}")
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)

    print(f"\nTotal duplicates removed: {duplicates_removed}")

    # Write the fixed content
    with open(project_path, 'w') as f:
        f.writelines(new_lines)

    print(f"Fixed project file: {project_path}")
    print(f"Backup saved as: {backup_path}")

if __name__ == '__main__':
    project_file = Path('/Users/iesouskurios/omniTAK-mobile/apps/omnitak/OmniTAKMobile.xcodeproj/project.pbxproj')

    if project_file.exists():
        print(f"Processing: {project_file}")
        fix_duplicate_build_files(project_file)
        print("\nDone! Rebuild the project to verify the fix.")
    else:
        print(f"Error: Project file not found at {project_file}")
