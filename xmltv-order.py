#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import sys

def fix_programme_icons(input_file, output_file):
    tree = ET.parse(input_file)
    root = tree.getroot()

    for prog in root.findall('programme'):
        desc = prog.find('desc')
        icon = prog.find('icon')
        image = prog.find('image')

        # Remove icon if it's misplaced
        if icon is not None:
            prog.remove(icon)

        # Create icon from image if icon is missing
        if icon is None and image is not None:
            icon = ET.Element('icon')
            icon.set('src', image.text.strip())

        # Insert icon after desc if icon exists and desc exists
        if desc is not None and icon is not None:
            # Insert icon right after desc
            desc_index = list(prog).index(desc)
            prog.insert(desc_index + 1, icon)

    tree.write(output_file, encoding="UTF-8", xml_declaration=True)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: fix_icons.py input.xml output.xml")
        sys.exit(1)
    fix_programme_icons(sys.argv[1], sys.argv[2])
    print(f"✅ Fixed XML written to {sys.argv[2]}")
