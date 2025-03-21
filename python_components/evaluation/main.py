import base64
from io import BytesIO

from deepeval import evaluate
from deepeval.metrics import MultimodalAnswerRelevancyMetric
from deepeval.test_case import MLLMTestCase, MLLMImage


from ollama import Client, AsyncClient, ChatResponse
from typing import Optional, Tuple, Union, Dict
from pydantic import BaseModel

from deepeval.models import DeepEvalBaseLLM, DeepEvalBaseMLLM
from deepeval.key_handler import KeyValues, KEY_FILE_HANDLER
import PIL.Image

#
# class MultimodalOllamaModel(DeepEvalBaseMLLM):
#
#     def __init__(
#         self,
#     ):
#         model_name = KEY_FILE_HANDLER.fetch_data(KeyValues.LOCAL_MODEL_NAME)
#         self.base_url = KEY_FILE_HANDLER.fetch_data(
#             KeyValues.LOCAL_EMBEDDING_BASE_URL
#         )
#         super().__init__(model_name)
#
#     ###############################################
#     # Other generate functions
#     ###############################################
#
#     def encode_pil_image(self, pil_image: "PILImage"):
#         image_buffer = BytesIO()
#         pil_image.save(image_buffer, format="JPEG")
#         image_bytes = image_buffer.getvalue()
#         base64_encoded_image = base64.b64encode(image_bytes).decode("utf-8")
#         return base64_encoded_image
#
#     def generate_prompt(
#         self, multimodal_input
#     ):
#         prompt = []
#         for ele in multimodal_input:
#             if isinstance(ele, str):
#                 prompt.append({"type": "text", "text": ele})
#             elif isinstance(ele, MLLMImage):
#                 if ele.local == True:
#                     import PIL.Image
#
#                     image = PIL.Image.open(ele.url)
#                     visual_dict = {
#                         "type": "image_url",
#                         "image_url": {
#                             "url": f"data:image/jpeg;base64,{self.encode_pil_image(image)}"
#                         },
#                     }
#                 else:
#                     visual_dict = {
#                         "type": "image_url",
#                         "image_url": {"url": ele.url},
#                     }
#                 prompt.append(visual_dict)
#         return prompt
#
#     def generate(
#             self, multimodal_input: list, schema = None
#     ) -> tuple:
#         chat_model = self.load_model()
#         prompt = self.generate_prompt(multimodal_input)
#         response = chat_model.chat(
#             model=self.model_name,
#             messages=[{"role": "user", "content": prompt}],
#             #format=schema.model_json_schema() if schema else None,
#         )
#         return (
#             response.message.content,
#             0,
#         )
#
#     async def a_generate(
#         self, prompt: str, schema: Optional[BaseModel] = None
#     ) -> Tuple[str, float]:
#         chat_model = self.load_model(async_mode=True)
#         model_name = KEY_FILE_HANDLER.fetch_data(KeyValues.LOCAL_MODEL_NAME)
#         response: ChatResponse = await chat_model.chat(
#             model=model_name,
#             messages=[{"role": "user", "content": prompt}],
#             format=schema.model_json_schema() if schema else None,
#         )
#         return (
#             (
#                 schema.model_validate_json(response.message.content)
#                 if schema
#                 else response.message.content
#             ),
#             0,
#         )
#
#     ###############################################
#     # Model
#     ###############################################
#
#     def load_model(self, async_mode: bool = False):
#         if not async_mode:
#             return Client(host=self.base_url)
#         else:
#             return AsyncClient(host=self.base_url)
#
#     def get_model_name(self):
#         return f"{self.model_name} (Ollama)"
#
#
# test = MultimodalOllamaModel()
# image_input = MLLMImage(url="data/page-0.jpg", local=True)
# o = test.generate(['Describe this image', image_input])
# print(o)

image_input = MLLMImage(url="data/page-0.jpg", local=True)
pil_image = PIL.Image.open(image_input.url)
image_buffer = BytesIO()
pil_image.save(image_buffer, format="JPEG")
image_bytes = image_buffer.getvalue()
base64_encoded_image = base64.b64encode(image_bytes).decode("utf-8")

import ollama
response = ollama.chat(model='gemma3:4b', messages=[
  {
    'role': 'user',
    'content': "What's in this image?",
    'images': [ base64_encoded_image ],
  },
])
print(response['message']['content'])