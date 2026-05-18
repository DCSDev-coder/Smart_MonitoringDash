import requests
import json

url = "http://219.92.246.237/itom/monitor/collectControlNode/byTypeForStatus"
try:
    response = requests.post(url, timeout=10)
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error: {e}")
