import sys
import os

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../")))

try:
    from utils.llm_clients.qwen_local import Qwen32bClient
    print("Successfully imported Qwen32bClient")
    
    # We won't instantiate it as it requires downloading 60GB model
    # client = Qwen32bClient()
    
except ImportError as e:
    print(f"Import failed: {e}")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
