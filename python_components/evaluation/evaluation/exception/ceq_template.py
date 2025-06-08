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

    @staticmethod
    def generate_reason(score: float, contradictions: List[str]):
        return f"""Below is a list of responses to close ended questions. It is a list of strings explaining why the 'actual output' did not answer a question about 'retrieval context'. These verdicts happen in the 'actual output', NOT the 'retrieval context'.
Given the close-ended question (CEQ) score, which is a 0-1 score indicating how aligned the `actual output` is to our subject matter expertise (higher the better), CONCISELY summarize the contradictions to justify the score.

**
IMPORTANT: Please make sure to only return in JSON format, with the 'reason' key providing the reason.
Example JSON:
{{
    "reason": "The score is <ceq_score> because <your_reason>."
}}

If there are no contradictions, just say something positive with an upbeat encouraging tone (but don't overdo it otherwise it gets annoying).
Your reason MUST use information in `contradiction` in your reason.
Be sure in your reason, as if you know what the actual output is from the contradictions.
**

CEQ Score:
{score}

Contradictions:
{contradictions}

JSON:
"""
