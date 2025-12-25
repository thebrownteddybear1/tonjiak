import json
import os

# Set the filename explicitly
CATALOG_FILE = 'productVersionCatalog.json'

def create_vcf_directories():
    if not os.path.exists(CATALOG_FILE):
        print(f"Error: {CATALOG_FILE} not found in the current directory.")
        return

    try:
        with open(CATALOG_FILE, 'r') as f:
            data = json.load(f)
            
        patches = data.get("patches", {})
        
        for category in patches.keys():
            # Create only the folders (ESX_HOST, VCENTER, etc.)
            if not os.path.exists(category):
                os.makedirs(category)
                print(f"Created Directory: {category}/")
            else:
                print(f"Directory already exists: {category}/")
                
    except json.JSONDecodeError:
        print(f"Error: {CATALOG_FILE} contains invalid JSON.")

if __name__ == "__main__":
    create_vcf_directories()