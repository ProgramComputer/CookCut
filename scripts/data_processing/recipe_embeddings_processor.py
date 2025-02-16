# Recipe Dataset Processor
# Dataset: Hieu-Pham/kaggle_food_recipes
# License: Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)
# Source: https://huggingface.co/datasets/Hieu-Pham/kaggle_food_recipes

import os
from dotenv import load_dotenv
import asyncio

# Load environment variables
load_dotenv()

from datasets import load_dataset
from openai import AsyncOpenAI
import numpy as np
from tqdm import tqdm
import time
import json
from datetime import datetime
import pinecone
from typing import List, Dict, Any
from pinecone import Pinecone, ServerlessSpec

class RecipeEmbeddingProcessor:
    def __init__(self):
        # Dataset info
        self.DATASET_INFO = {
            "name": "Hieu-Pham/kaggle_food_recipes",
            "license": "CC BY-SA 3.0",
            "license_url": "https://creativecommons.org/licenses/by-sa/3.0/",
            "source": "https://huggingface.co/datasets/Hieu-Pham/kaggle_food_recipes"
        }
        
        # Initialize OpenAI
        self.client = AsyncOpenAI()
        
        # Constants
        self.BATCH_SIZE = 50
        self.EMBEDDING_MODEL = "text-embedding-3-small"
        self.RETRY_DELAY = 5
        self.MAX_RETRIES = 3
        
        # RAG optimization constants
        self.MAX_CHUNK_SIZE = 500  # characters
        self.CHUNK_OVERLAP = 100   # characters
        
        # Initialize Pinecone
        pc = Pinecone(api_key=os.getenv('PINECONE_API_KEY'))
        
        # Get index name from environment variables
        self.INDEX_NAME = os.getenv('PINECONE_INDEX_NAME', 'cookcutrecipes')
        self.VECTOR_DIM = 1536  # text-embedding-3-small dimension
        
        # Get or create index
        if self.INDEX_NAME not in pc.list_indexes().names():
            print(f"Creating new index: {self.INDEX_NAME}")
            pc.create_index(
                name=self.INDEX_NAME,
                dimension=self.VECTOR_DIM,
                metric="cosine",
                spec=ServerlessSpec(
                    cloud='aws',
                    region='us-east-1'
                )
            )
        else:
            print(f"Using existing index: {self.INDEX_NAME}")
        
        self.index = pc.Index(self.INDEX_NAME)
        
    def chunk_text(self, text, max_length=None):
        """Split text into overlapping chunks for better RAG retrieval"""
        if max_length is None:
            max_length = self.MAX_CHUNK_SIZE
            
        if len(text) <= max_length:
            return [text]
            
        chunks = []
        start = 0
        while start < len(text):
            # Find the end of the chunk
            end = start + max_length
            if end < len(text):
                # Try to end at a sentence or period
                next_period = text.find('.', end - 50, end + 50)
                if next_period != -1:
                    end = next_period + 1
            
            chunks.append(text[start:end].strip())
            start = end - self.CHUNK_OVERLAP
            
        return chunks

    def prepare_recipe_text(self, recipe):
        """Prepare recipe text optimized for RAG"""
        # Separate different components for targeted retrieval
        title = f"Recipe: {recipe['Title']}"
        
        ingredients = "Ingredients:\n" + "\n".join(
            f"- {ing}" for ing in (recipe['Cleaned_Ingredients'] if recipe['Cleaned_Ingredients'] else recipe['Ingredients'])
        )
        
        # Chunk the instructions
        instruction_chunks = self.chunk_text(recipe['Instructions'])
        instructions = [f"Instructions Part {i+1}/{len(instruction_chunks)}:\n{chunk}" 
                       for i, chunk in enumerate(instruction_chunks)]
        
        # Create separate embeddings for each component
        return {
            'title': title,
            'ingredients': ingredients,
            'instructions': instructions
        }
    
    async def get_embedding(self, text, retries=0):
        """Get embedding with retry logic"""
        try:
            text = text.replace("\n", " ")
            response = await self.client.embeddings.create(
                input=[text],
                model=self.EMBEDDING_MODEL
            )
            return response.data[0].embedding
        except Exception as e:
            if retries < self.MAX_RETRIES:
                print(f"Error getting embedding, retrying in {self.RETRY_DELAY} seconds...")
                time.sleep(self.RETRY_DELAY)
                return await self.get_embedding(text, retries + 1)
            else:
                raise e

    async def get_embeddings(self, texts):
        """Get embeddings for multiple texts"""
        try:
            response = await self.client.embeddings.create(
                input=texts,
                model=self.EMBEDDING_MODEL
            )
            return [data.embedding for data in response.data]
        except Exception as e:
            print(f"Error getting embeddings: {str(e)}")
            raise e

    def store_batch(self, batch_data):
        """Store recipe vectors in Pinecone"""
        try:
            # Prepare vectors for Pinecone
            vectors_to_upsert = []
            
            for recipe_data in batch_data:
                # Generate a unique ID for the recipe
                recipe_id = str(hash(recipe_data['title']))
                
                # Convert numpy arrays to lists if needed
                title_embedding = recipe_data['title_embedding'].tolist() if isinstance(recipe_data['title_embedding'], np.ndarray) else recipe_data['title_embedding']
                ingredients_embedding = recipe_data['ingredients_embedding'].tolist() if isinstance(recipe_data['ingredients_embedding'], np.ndarray) else recipe_data['ingredients_embedding']
                
                # Title vector
                vectors_to_upsert.append({
                    'id': f"{recipe_id}_title",
                    'values': title_embedding,
                    'metadata': {
                        'recipe_id': recipe_id,
                        'type': 'title',
                        'text': recipe_data['title'],
                        'image_name': recipe_data.get('image_name', '')
                    }
                })
                
                # Ingredients vector
                vectors_to_upsert.append({
                    'id': f"{recipe_id}_ingredients",
                    'values': ingredients_embedding,
                    'metadata': {
                        'recipe_id': recipe_id,
                        'type': 'ingredients',
                        'text': recipe_data['ingredients']
                    }
                })
                
                # Instruction chunks
                for i, (chunk, embedding) in enumerate(zip(
                    recipe_data['instruction_chunks'],
                    recipe_data['instruction_embeddings']
                )):
                    chunk_embedding = embedding.tolist() if isinstance(embedding, np.ndarray) else embedding
                    
                    vectors_to_upsert.append({
                        'id': f"{recipe_id}_instruction_{i}",
                        'values': chunk_embedding,
                        'metadata': {
                            'recipe_id': recipe_id,
                            'type': 'instruction',
                            'chunk_order': i,
                            'total_chunks': len(recipe_data['instruction_chunks']),
                            'text': chunk
                        }
                    })
            
            # Upsert to Pinecone in smaller batches
            PINECONE_BATCH_SIZE = 100
            for i in range(0, len(vectors_to_upsert), PINECONE_BATCH_SIZE):
                batch = vectors_to_upsert[i:i + PINECONE_BATCH_SIZE]
                self.index.upsert(vectors=batch)
            
            return True
            
        except Exception as e:
            print(f"Error in batch write: {str(e)}")
            return False
    
    async def process_recipes(self):
        """Main processing function with RAG optimization"""
        print(f"Loading dataset: {self.DATASET_INFO['name']}")
        dataset = load_dataset(self.DATASET_INFO['name'])
        recipes = dataset['train']
        
        current_batch = []
        processed_count = 0
        
        progress_bar = tqdm(total=len(recipes), desc="Processing recipes")
        
        for recipe in recipes:
            try:
                # Prepare text components
                texts = self.prepare_recipe_text(recipe)
                
                # Get embeddings for all components
                title_embedding = await self.get_embedding(texts['title'])
                ingredients_embedding = await self.get_embedding(texts['ingredients'])
                instruction_embeddings = await self.get_embeddings(texts['instructions'])
                
                # Prepare document
                recipe_doc = {
                    'title': texts['title'],
                    'title_embedding': title_embedding,
                    'ingredients': texts['ingredients'],
                    'ingredients_embedding': ingredients_embedding,
                    'instruction_chunks': texts['instructions'],
                    'instruction_embeddings': instruction_embeddings,
                    'image_name': recipe.get('Image_Name', '')
                }
                
                current_batch.append(recipe_doc)
                
                if len(current_batch) >= self.BATCH_SIZE:
                    if self.store_batch(current_batch):
                        processed_count += len(current_batch)
                    current_batch = []
                
                progress_bar.update(1)
                
            except Exception as e:
                print(f"Error processing recipe {recipe.get('Title', 'Unknown')}: {str(e)}")
                
        # Process remaining recipes
        if current_batch:
            if self.store_batch(current_batch):
                processed_count += len(current_batch)
        
        progress_bar.close()
        print(f"Successfully processed {processed_count} recipes")

    async def semantic_search(self, query: str, search_type: str = 'all', top_k: int = 5) -> List[Dict[str, Any]]:
        """
        Perform semantic search across recipes
        search_type: 'all', 'title', 'ingredients', or 'instructions'
        """
        # Get query embedding
        query_embedding = await self.get_embedding(query)
        
        # Search in Pinecone
        filter = {"type": search_type} if search_type != 'all' else {}
        results = self.index.query(
            vector=query_embedding,
            filter=filter,
            top_k=top_k,
            include_metadata=True
        )
        
        return results

def main():
    processor = RecipeEmbeddingProcessor()
    asyncio.run(processor.process_recipes())

if __name__ == "__main__":
    main() 