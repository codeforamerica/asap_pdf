from tqdm import tqdm
import pandas as pd
import requests
import time
import json

examples = [
    ["MINUTES%20December%202024.pdf", "https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf", "Agenda"],
    ["VA S.A.V.E. Training One-Pager", "https://www.mentalhealth.va.gov/suicide_prevention/docs/VA_SAVE_Training.pdf", "Brochure"],
    ["atlanta-market-map.pdf", "https://agr.georgia.gov/sites/default/files/documents/agritourism/atlanta-market-map.pdf", "Diagram"],
    ["Microsoft Word - One-page reasonable accommodation form.docx", "https://www.austintexas.gov/sites/default/files/files/HR/One-page_reasonable_accommodation_form.pdf", "Form"],
    ["2013.07.16_PlanningCommission.pdf", "http://www.slcdocs.com/attorney/COI/2013.07.16_PlanningCommission.pdf", "Letter"],
    ["Font Size:  12", "https://services.austintexas.gov/edims/document.cfm?id=446835", "Notice"],
    ["08.14.15.14.pdf", "https://nathandeal.georgia.gov/sites/nathandeal.georgia.gov/files/related_files/document/08.14.15.14.pdf", "Policy"],
    ["5.b-Vacancies-on-Boards-and-Commissions.pdf", "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2021/07/5.b-Vacancies-on-Boards-and-Commissions.pdf", "Report"],
    ["Microsoft PowerPoint - Council Workession Update on Bond Development 4-3-17 FINAL.pptx", "https://services.austintexas.gov/edims/document.cfm?id=274486", "Slides"],
    ["July-2016-WCE-Salary-Schedule.pdf", "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2016/09/July-2016-WCE-Salary-Schedule.pdf", "Spreadsheet"]
]

if __name__ == "__main__":
    responses = []
    for example in examples:
        document_title = example[0]
        document_url = example[1]
        document_purpose = example[2]
        print(f"{document_title} {document_purpose} {document_url}")
        for i in tqdm(range(10)):
            response = requests.get(
                "http://localhost:9001/2015-03-31/functions/function/invocations",
                data=json.dumps({
                    "model_name": "claude-3.7-sonnet", # "claude-3.5-haiku", # "gemini-2.0-pro-exp-02-05",
                    "page_limit": 7,
                    "documents": [{
                        "title": document_title,
                        "id": "000", # Does this matter?
                        "purpose": document_purpose,
                        "url": document_url
                    }]
                })
            )
            if response.json()['statusCode'] != 200:
                print('Error reading response: ', response.json())
                continue

            record = pd.DataFrame(response.json()['body'])
            record['title'] = document_title
            record['url'] = document_url
            record['purpose'] = document_purpose
            responses.append(record)
            time.sleep(25)

    df = pd.concat(responses)
    df.to_csv("eligibility_results_claude_sonnet.csv", index=False)