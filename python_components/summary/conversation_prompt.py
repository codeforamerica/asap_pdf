import argparse
import json
import logging

import llm
import pdf2image
import pypdf

# Create and provide a very simple logger implementation.
logger = logging.getLogger('experiment_utility')
formatter = logging.Formatter('%(asctime)s: %(message)s')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
ch.setFormatter(formatter)
logger.addHandler(ch)


def get_config():
    with open('config.json', 'r') as f:
        return json.load(f)


def pdf_to_attachments(pdf_path: str, output_path: str, page_limit: int) -> list:
    images = pdf2image.convert_from_path(pdf_path, fmt='jpg')
    attachments = []
    for page, image in enumerate(images):
        if 0 < page_limit - 1 < page:
            break
        page_path = f'{output_path}/page-{page}.jpg'
        image.save(page_path)
        attachments.append(llm.Attachment(path=page_path, type='image/jpeg'))
    return attachments


total_tokens_used = {
    'input': 0,
    'output': 0,
}

PROMPT = """
# Government PDF ADA Compliance Exception Analyzer

You are an AI assistant specializing in ADA compliance analysis. Your task is to analyze government PDF documents and determine whether they qualify for an exception under the Department of Justice's 2024 final rule on web content and mobile app accessibility.

## Context

The Department of Justice published a final rule updating regulations for Title II of the Americans with Disabilities Act (ADA). This rule requires state and local governments to ensure their web content and mobile apps are accessible to people with disabilities according to WCAG 2.1, Level AA standards. However, certain PDF documents may qualify for exceptions.

## Your Task

The attached jpeg documents represent a PDF. Analyze the PDF document information and determine whether it qualifies for an exception from WCAG 2.1, Level AA compliance requirements under one of the following exception categories:

1. **Archived Web Content Exception** - Applies when ALL of these conditions are met:
   - Created before the compliance date April 24, 2026
   - Kept only for reference, research, or recordkeeping
   - Stored in a special area for archived content
   - Has not been changed since it was archived

2. **Preexisting Conventional Electronic Documents Exception** - Applies when ALL conditions are met:
   - Document is a PDF file
   - Document was available on the government's website or mobile app before the compliance date
   - HOWEVER: This exception does NOT apply if the document is currently being used by individuals to apply for, access, or participate in government services

3. **Content Posted by Third Parties Exception** - Applies when:
   - Content is posted by third parties (members of the public or others not controlled by or acting for government entities)
   - The third party is not posting due to contractual, licensing, or other arrangements with the government entity
   - HOWEVER: This exception does NOT apply to content posted by the government itself, content posted by government contractors/vendors, or to tools/platforms that allow third parties to post content

## Document Information

  - Document title: 2023 Gann Appropriations Limit Report
  - Document purpose: Report
  - Document URL: https://www.cityofsanrafael.org/documents/san-rafael-gann-2023

"""

def run_experiment(pdf_path: str):
    output = {
        'is_encrypted': pypdf.PdfReader(pdf_path).is_encrypted,
        'summary': '',
        'is_third_party': None,
        'why_third_party': '',
        'is_archival': None,
        'why_archival': '',
        'is_app': None,
        'why_app': '',
        'tokens': {},
    }
    if not output['is_encrypted']:
        config = get_config()
        model = llm.get_model(config['active_model'])
        model.key = config['key']
        attachments = pdf_to_attachments(pdf_path, './data', config['page_limit'])
        conversation = model.conversation()
        run_prompt(conversation, PROMPT)
        boolean_answers = ('True', 'False')
        response = run_prompt(conversation,
                              'True or False does this document meet the "Archived Web Content Exception" exception criteria? ONLY OUTPUT: True or False')
        assert response.text().strip() in boolean_answers
        output['is_archival'] = response.text().strip() == 'True'
        response = run_prompt(conversation, 'Provide a one sentence explanation of your answer.')
        output['why_archival'] = response.text().strip()
        response = run_prompt(conversation,
                              'True or False does this document meet the "Preexisting Conventional Electronic Documents Exception" exception criteria? ONLY OUTPUT: True or False')
        assert response.text().strip() in boolean_answers
        output['is_app'] = response.text().strip() == 'True'
        response = run_prompt(conversation, 'Provide a one sentence explanation of your answer.')
        output['why_app'] = response.text().strip()

        response = run_prompt(conversation,
                              'True or False does this document meet the "Content Posted by Third Parties Exception" exception criteria? ONLY OUTPUT: True or False')
        assert response.text().strip() in boolean_answers
        output['is_third_party'] = response.text().strip() == 'True'
        response = run_prompt(conversation, 'Provide a one sentence explanation of your answer.')
        output['why_third_party'] = response.text().strip()

        response = run_prompt(conversation,
                              'The following jpg images are the pages from the document. Could you summarize the document in two to three sentences?',
                              attachments=attachments)

        output['summary'] = response.text()
        output['tokens'] = total_tokens_used
    print(json.dumps(output))


def run_prompt(conversation, prompt, attachments=None):
    global total_tokens_used
    if attachments is None:
        response = conversation.prompt(prompt)
    else:
        response = conversation.prompt(prompt, attachments=attachments)
    usage = response.usage()
    total_tokens_used['input'] += usage.input
    total_tokens_used['output'] += usage.output
    return response


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Ask an LLM all kinds of questions about a document.")
    parser.add_argument("pdf_path", help="Path to pdf")
    args = parser.parse_args()
    run_experiment(args.pdf_path)
