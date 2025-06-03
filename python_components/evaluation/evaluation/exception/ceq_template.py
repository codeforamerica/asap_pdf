from typing import List, Optional


class CEQTemplate:

    @staticmethod
    def get_verdicts(
        document_metadata: str,
        ai_text: str,
        questions: List[str],
        additional_context: Optional[str] = "",
    ) -> str:
        return f"""Based on the provided "Evaluation Text" answer the following close ended questions, labeled as "Questions" with JSON. The JSON will have 2 fields: 'verdict' and 'reason'.
The 'verdict' key should STRICTLY be either 'yes', 'no', or 'idk', which states whether the given question is answered by the "Evaluation Text". 
Provide a 'reason' ONLY if the answer is 'no' OR 'idk'.

You should include "Document Metadata" in your reasoning.

{additional_context}

Document Metadata:
{document_metadata}

Evaluation Text:
{ai_text}

Questions:
{questions}

**
IMPORTANT: Please make sure to only return in JSON format, with the 'answers' key as a list of strings.

Example:
Example Text: Mario and Luigi were best buds but since Luigi had a crush on Peach Mario ended up killing him.
Example Questions: ["Does the text mention names other than Mario?", "Does the text mention bowser?", "Who is the author of the text?"]
Example Answers:
{{
    "verdicts": [
        {{
            "verdict": "yes"
        }},
        {{
            "verdict": "no",
            "reason": "The text does not mention bowser."
        }},
        {{
            "verdict": "idk",
            "reason": "No author is stated. Not enough information is provided."
        }},
    ]
}}

The length of 'answers' SHOULD BE STRICTLY EQUAL to that of questions.
===== END OF EXAMPLE ======

JSON:
"""
