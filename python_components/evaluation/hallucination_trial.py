from deepeval import evaluate
from deepeval.metrics import HallucinationMetric, FaithfulnessMetric
from deepeval.test_case import LLMTestCase, MLLMImage
from deepeval.models import MultimodalGeminiModel

from evaluation.utility.document import Document

from evaluation.exception.faithfulness_score import evaluate_faithfulness

model = MultimodalGeminiModel(api_key="AIzaSyC742WofeucCI-KaaiZJmcVz9YEbnMgMLE", model_name="gemini-2.5-pro-preview-03-25")

#with open('test.txt') as file:
#    full_input_text = file.read()

#actual_output="The document was created on November 11, 2022, before the compliance date. However, it is not confirmed to be stored in a 'special area for archived content,' as the URL (.../wp-content/uploads/...) suggests a general file upload directory rather than a designated archive. It is also unknown if it has remained unchanged since its original posting. Since not all conditions for the Archived Web Content Exception are verifiably met, particularly the dedicated archival storage, it does not qualify."

# Replace this with the actual documents that you are passing as input to your LLM.
# context=["This ADA rule exempts archived web content from WCAG 2.1 Level AA accessibility requirements if it meets all four criteria: the content was created before the compliance deadline or reproduces pre-compliance physical documents, it's kept only for reference/research/recordkeeping purposes, and it's stored in a designated archive area. The content must also remain completely unchanged since being archived. All four conditions must be satisfied simultaneously for the exemption to apply."]
#
# # Replace this with the actual output from your LLM application
#
# test_case = LLMTestCase(
#     input=full_input_text,
#     actual_output=actual_output,
#     context=context
# )
# metric = HallucinationMetric(threshold=0.5, model=model)
#
# # To run metric as a standalone
# # metric.measure(test_case)
# # print(metric.score, metric.reason)
#
# evaluate(test_cases=[test_case], metrics=[metric])

# Replace this with the actual retrieved context from your RAG pipeline
# context=[
#     "This ADA rule exempts archived web content from WCAG 2.1 Level AA accessibility requirements if it meets all four criteria: the content was created before the compliance deadline or reproduces pre-compliance physical documents, it's kept only for reference/research/recordkeeping purposes, and it's stored in a designated archive area. The content must also remain completely unchanged since being archived. All four conditions must be satisfied simultaneously for the exemption to apply.",
#     full_input_text]
#
# metric = FaithfulnessMetric(
#     threshold=0.7,
#     model=model,
#     include_reason=True,
#     verbose_mode=True,
# )
# test_case = LLMTestCase(
#     input='',
#     actual_output=actual_output,
#     retrieval_context=context
# )
#
# # To run metric as a standalone
# metric.measure(test_case)
# print(metric.score, metric.reason)

#evaluate(test_cases=[test_case], metrics=[metric])


extra_context=["This ADA rule exempts archived web content from WCAG 2.1 Level AA accessibility requirements if it meets all four criteria: the content was created before the compliance deadline or reproduces pre-compliance physical documents, it's kept only for reference/research/recordkeeping purposes, and it's stored in a designated archive area. The content must also remain completely unchanged since being archived. All four conditions must be satisfied simultaneously for the exemption to apply."]

s = Document.model_validate_json('{"file_name": "MINUTES%20December%202024.pdf", "category": "Agenda", "url": "https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf", "human_summary": "Minutes for a December 12 2024 meeting of the Georgia Structural Pest Control Commission. During the meeting there were updates from the UGA Urban Entomology, Compliance and Enforcement, Certification and Training, among others.", "created_date": "2025-01-08 14:11:03","modification_date": "2025-01-08 14:11:05", "human_exception": {"is_archival": "True"}}')

s.human_exception = {
  "is_archival": False,
}

s.ai_exception = {
    "is_archival": False,
    "why_archival": 'Although labeled as "Minutes", the document\'s context suggests it is part of active recordkeeping, rather than archived materials. The content discusses ongoing activities and future plans, indicating it\'s not solely for historical reference or research, and likely subject to change.',
}

s.images = [
    MLLMImage('/tmp/data/MINUTES%20December%202024/images/MINUTES%20December%202024-0.jpg', local=True),
    MLLMImage('/tmp/data/MINUTES%20December%202024/images/MINUTES%20December%202024-1.jpg', local=True),
    MLLMImage('/tmp/data/MINUTES%20December%202024/images/MINUTES%20December%202024-2.jpg', local=True),
    MLLMImage('/tmp/data/MINUTES%20December%202024/images/MINUTES%20December%202024-3.jpg', local=True),
    MLLMImage('/tmp/data/MINUTES%20December%202024/images/MINUTES%20December%202024-4.jpg', local=True)
]

r = evaluate_faithfulness("asap-156-add-ai-exeption-check-eval","54321e", s, model, extra_context, s.ai_exception["why_archival"])


print(r)