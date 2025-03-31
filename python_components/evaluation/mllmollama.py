import base64
from io import BytesIO

from deepeval import evaluate
from deepeval.metrics import MultimodalAnswerRelevancyMetric, MultimodalContextualPrecisionMetric, SummarizationMetric
from deepeval.test_case import MLLMTestCase, MLLMImage, LLMTestCase

from ollama import Client, AsyncClient, ChatResponse
from typing import Optional, Tuple, Union, Dict
from pydantic import BaseModel

from deepeval.models import DeepEvalBaseLLM, DeepEvalBaseMLLM
from deepeval.key_handler import KeyValues, KEY_FILE_HANDLER
import PIL.Image


class MultimodalOllamaModel(DeepEvalBaseMLLM):

    def __init__(
            self,
    ):
        model_name = KEY_FILE_HANDLER.fetch_data(KeyValues.LOCAL_MODEL_NAME)
        self.base_url = KEY_FILE_HANDLER.fetch_data(
            KeyValues.LOCAL_MODEL_BASE_URL
        )
        super().__init__(model_name)

    ###############################################
    # Other generate functions
    ###############################################

    def generate_prompt(
            self, multimodal_input
    ):
        prompt = {
            'text': "",
            'images': []
        }
        for ele in multimodal_input:
            if isinstance(ele, str):
                prompt['text'] += f"{ele}\n"
            elif isinstance(ele, MLLMImage):
                image = PIL.Image.open(ele.url)
                prompt['images'].append(encode_pil_image(image))
        return prompt

    def generate(
            self, multimodal_input: list, schema=None
    ):
        chat_model = self.load_model()
        prompt = self.generate_prompt(multimodal_input)
        response = chat_model.chat(
            model=self.model_name,
            messages=[{
                'role': 'user',
                'content': prompt["text"],
                'images': prompt["images"] if len(prompt["images"]) > 0 else None,
            }],
            format=schema.model_json_schema() if schema else None,
        )
        return schema.model_validate_json(response.message.content) if schema else response.message.content


    async def a_generate(
            self, multimodal_input: list, schema: Optional[BaseModel] = None
    ):
        chat_model = self.load_model(async_mode=True)
        prompt = self.generate_prompt(multimodal_input)
        response = await chat_model.chat(
            model=self.model_name,
            messages=[{
                'role': 'user',
                'content': prompt["text"],
                'images': prompt["images"] if len(prompt["images"]) > 0 else None,
            }],
            format=schema.model_json_schema() if schema else None,
        )
        return schema.model_validate_json(response.message.content) if schema else response.message.content

    ###############################################
    # Model
    ###############################################

    def load_model(self, async_mode: bool = False):
        if not async_mode:
            return Client(host=self.base_url)
        else:
            return AsyncClient(host=self.base_url)

    def get_model_name(self):
        return f"{self.model_name} (Ollama)"



def encode_pil_image(pil_image: PIL.Image):
    image_buffer = BytesIO()
    pil_image.save(image_buffer, format="JPEG")
    image_bytes = image_buffer.getvalue()
    base64_encoded_image = base64.b64encode(image_bytes).decode("utf-8")
    return base64_encoded_image