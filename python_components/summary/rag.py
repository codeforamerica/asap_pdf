import base64
import json
import os

import bs4
import httpx
import pdf2image
from langchain import hub
from langchain.chat_models import init_chat_model
from langchain_community.document_loaders import TextLoader
from langchain_core.documents import Document
from langchain_core.messages import HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.vectorstores import InMemoryVectorStore
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langgraph.graph import START, StateGraph
from pydantic import BaseModel, Field
from typing_extensions import List, TypedDict


def get_config():
    with open('config.json', 'r') as f:
        return json.load(f)

config = get_config()


if not os.environ.get("ANTHROPIC_API_KEY"):
    os.environ["ANTHROPIC_API_KEY"] = config['key']




def encode_image(image_path):
   """Getting the base64 string"""
   with open(image_path, "rb") as image_file:
       return base64.b64encode(image_file.read()).decode("utf-8")


def image_summarize(img_base64, prompt):
   """Make image summary"""
   model = init_chat_model("claude-3-5-haiku-latest", model_provider="anthropic")

   msg = model(
       [
           HumanMessage(
               content=[
                   {"type": "text", "text": prompt},
                   {
                       "type": "image_url",
                       "image_url": {"url": f"data:image/jpeg;base64,{img_base64}"},
                   },
               ]
           )
       ]
   )
   return msg.content


def generate_img_summaries(path):
   """
   Generate summaries and base64 encoded strings for images
   path: Path to list of .jpg files extracted by Unstructured
   """

   # Store base64 encoded images
   img_base64_list = []

   # Store image summaries
   image_summaries = ["Official accounting report for City of San Rafael, California's 2023-2024 Proposition 111 Appropriations Limit Increment, prepared by Maze & Associates, detailing independent accountant's review of municipal financial compliance procedures and worksheet.", 'Official document disclaimer page from Marge & Associates, located in Pleasant Hill, California, dated November 20, 2023, describing ethical reporting and information distribution guidelines for a city council report.']

   # Prompt
   prompt = """You are an assistant tasked with summarizing images for retrieval. \
   These summaries will be embedded and used to retrieve the raw image. \
   Give a concise summary of the image that is well optimized for retrieval."""

   # Apply to images
   for img_file in sorted(os.listdir(path)):
       if img_file.endswith(".jpg"):
           img_path = os.path.join(path, img_file)
           base64_image = encode_image(img_path)
           img_base64_list.append(base64_image)
           #image_summaries.append(image_summarize(base64_image, prompt))

   return img_base64_list, image_summaries


# Image summaries
img_base64_list, image_summaries = generate_img_summaries("./data")


os.environ["LANGSMITH_TRACING"] = "true"
os.environ["LANGSMITH_API_KEY"] = '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'

llm = init_chat_model("claude-3-5-haiku-latest", model_provider="anthropic")

# llm.with_structured_output(DocumentEligibility)

embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-mpnet-base-v2")
loader = TextLoader(file_path='./data/web-rule.txt')
docs = loader.load()

vector_store = InMemoryVectorStore(embeddings)

text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
all_splits = text_splitter.split_documents(docs)

_ = vector_store.add_documents(documents=all_splits)


# Define state for application
class State(TypedDict):
    question: str
    context: List[Document]
    answer: str


prompt = hub.pull("rlm/rag-prompt")

# Define application steps
def retrieve(state: State):
    retrieved_docs = vector_store.similarity_search(state["question"])
    return {"context": retrieved_docs}


def generate(state: State):
    docs_content = "\n\n".join(doc.page_content for doc in state["context"])
    messages = prompt.invoke({"question": state["question"], "context": docs_content})
    response = llm.invoke(messages)
    return {"answer": response.content}


# Compile application and test
graph_builder = StateGraph(State).add_sequence([retrieve, generate])
graph_builder.add_edge(START, "retrieve")
graph = graph_builder.compile()

question = {"question": f"The document is titled '2023 Gann Appropriations Limit Report' and is located at 'https://www.cityofsanrafael.org/documents/san-rafael-gann-2023'. Here are summaries of the document's two pages: {image_summaries[0]}, {image_summaries[1]}. Why or why not is the document exempt from the ADA rule?"}
response = graph.invoke(question)
print(response["answer"])


# if not os.environ.get("ANTHROPIC_API_KEY"):
#     os.environ["ANTHROPIC_API_KEY"] = config['key']
#
#
# model = init_chat_model("claude-3-5-haiku-latest", model_provider="anthropic")
#
# image_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"
# image_data = base64.b64encode(httpx.get(image_url).content).decode("utf-8")
#
# prompt = ChatPromptTemplate.from_messages(
#     [
#         ("system", "Describe the image provided"),
#         (
#             "user",
#             [
#                 {
#                     "type": "image_url",
#                     "image_url": {"url": "data:image/jpeg;base64,{image_data}"},
#                 }
#             ],
#         ),
#     ]
# )
#
# chain = prompt | model
#
# response = chain.invoke({"image_data": image_data})
# print(response.content)
