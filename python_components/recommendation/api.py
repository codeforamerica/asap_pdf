import requests
import json

url = 'http://127.0.0.1:3000/api/documents/17/inference'

# Data to be sent in the request body
data = {
    'documents': [{'type': 'summary', 'value': 'Here is the summary.', 'reason': 'we do not need one'}]
}

# Headers (optional, but often needed for specifying content type)
headers = {'Content-type': 'application/json'}

# Send the POST request
response = requests.post(url, data=json.dumps(data), headers=headers)

# Check the response status code
if response.status_code == 200:
    print('Request successful!')
    # Process the response data (if any)
    print(response.json())
else:
    print(f'Request failed with status code {response.status_code}')
    print(response.text)