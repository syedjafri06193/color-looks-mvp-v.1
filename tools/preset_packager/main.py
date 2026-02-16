import zipfile
import sys
import os

if len(sys.argv) < 3:
    print("Usage: preset_packager <input_folder> <output.zip>")
    sys.exit(1)

input_folder = sys.argv[1]
output_file = sys.argv[2]

with zipfile.ZipFile(output_file, 'w') as z:
    for root, dirs, files in os.walk(input_folder):
        for file in files:
            path = os.path.join(root, file)
            z.write(path)

print("Packaged:", output_file)
