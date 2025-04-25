import argparse

import pandas as pd
from deepeval.models import MultimodalGeminiModel

from evaluation import summary, utility

model = MultimodalGeminiModel(model="gemini-2.5-pro-preview-03-25")

examples = [
    ["MINUTES%20December%202024.pdf",
     "https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf", "Agenda"],
    # ["VA S.A.V.E. Training One-Pager", "https://www.mentalhealth.va.gov/suicide_prevention/docs/VA_SAVE_Training.pdf",
    #  "Brochure"],
    # ["atlanta-market-map.pdf",
    #  "https://agr.georgia.gov/sites/default/files/documents/agritourism/atlanta-market-map.pdf", "Diagram"],
    # ["Microsoft Word - One-page reasonable accommodation form.docx",
    #  "https://www.austintexas.gov/sites/default/files/files/HR/One-page_reasonable_accommodation_form.pdf", "Form"],
    # ["2013.07.16_PlanningCommission.pdf", "http://www.slcdocs.com/attorney/COI/2013.07.16_PlanningCommission.pdf",
    #  "Letter"],
    # ["Font Size:  12", "https://services.austintexas.gov/edims/document.cfm?id=446835", "Notice"],
    # ["08.14.15.14.pdf",
    #  "https://nathandeal.georgia.gov/sites/nathandeal.georgia.gov/files/related_files/document/08.14.15.14.pdf",
    #  "Policy"],
    # ["5.b-Vacancies-on-Boards-and-Commissions.pdf",
    #  "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2021/07/5.b-Vacancies-on-Boards-and-Commissions.pdf",
    #  "Report"],
    # ["Microsoft PowerPoint - Council Workession Update on Bond Development 4-3-17 FINAL.pptx",
    #  "https://services.austintexas.gov/edims/document.cfm?id=274486", "Slides"],
    # ["July-2016-WCE-Salary-Schedule.pdf",
    #  "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2016/09/July-2016-WCE-Salary-Schedule.pdf",
    #  "Spreadsheet"]
]

def run_evaluation(output_path: str):
    # Build summaries with current branch.
    df = pd.DataFrame(examples)
    df.transpose()
    df.columns = ['file_name', 'url', 'category']
    df['summary'] = df.apply(summary.get_summaries, axis=1, args=('gemini-1.5-pro-latest',))
    df['images'] = df.apply(utility.document.convert_to_images, axis=1, args=(output_path,))
    df[['score', 'reason', 'detail']] = df.apply(summary.evaluation, axis=1, result_type='expand', args=(model,))
    df.to_csv(f"{output_path}/output.csv", index=False)

def handler(event, context):
    pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Runs evals on one or more truthset documents.."
    )
    parser.add_argument("output_path", help="Path to dump evaluation results.")
    args = parser.parse_args()
    run_evaluation(args.output_path)