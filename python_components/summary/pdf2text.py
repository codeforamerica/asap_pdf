import argparse
import re

from pdfminer.high_level import extract_text


def pdf_to_text_pdfminer(pdf_path):
    text = extract_text(pdf_path)
    return re.sub(r'\n\s*\n', '\n\n', text)


def output_text(output_path, text):
    with open(output_path, 'w') as file:
        file.write(text)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Ask an LLM to respond in structured output.")
    parser.add_argument("pdf_path", help="Path to pdf")
    parser.add_argument("output_path", help="Path to put text")
    args = parser.parse_args()
    text = pdf_to_text_pdfminer(args.pdf_path)
    output_text(args.output_path, text)