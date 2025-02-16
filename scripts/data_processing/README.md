# Recipe Data Processing Scripts

This directory contains scripts for processing recipe data and generating embeddings for the CookCut application.

## Recipe Embeddings Processor

The `recipe_embeddings_processor.py` script processes recipes from the [Hieu-Pham/kaggle_food_recipes](https://huggingface.co/datasets/Hieu-Pham/kaggle_food_recipes) dataset, generates embeddings using OpenAI's text-embedding-3-small model, and stores them in Firebase Firestore.

### Setup

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Set up environment variables:
```bash
export OPENAI_API_KEY='your-openai-api-key'
```

3. Place your Firebase credentials JSON file at `../.env/firebase-credentials.json`

### Usage

Run the script:
```bash
python recipe_embeddings_processor.py
```

The script will:
- Load recipes from HuggingFace
- Generate embeddings using OpenAI's text-embedding-3-small model
- Store recipes and embeddings in Firestore
- Create a detailed log file with processing statistics

### Output

The script creates:
- Firestore documents in the 'recipes' collection
- A processing log file with timestamp, statistics, and any errors

### Data Structure

Each recipe document in Firestore contains:
- Title
- Ingredients (original and cleaned)
- Instructions
- Embedding vector
- Metadata (processing timestamp, image name, license info)

## License

### Dataset License
The recipe dataset ([Hieu-Pham/kaggle_food_recipes](https://huggingface.co/datasets/Hieu-Pham/kaggle_food_recipes)) is licensed under the Creative Commons Attribution-ShareAlike 3.0 Unported License (CC BY-SA 3.0).

You are free to:
- Share — copy and redistribute the material in any medium or format
- Adapt — remix, transform, and build upon the material for any purpose, even commercially

Under the following terms:
- Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made
- ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original

For more details, see the full [CC BY-SA 3.0 License](https://creativecommons.org/licenses/by-sa/3.0/).

### Attribution
This project uses the kaggle_food_recipes dataset created by Hieu-Pham, available at:
https://huggingface.co/datasets/Hieu-Pham/kaggle_food_recipes

Original source: https://www.kaggle.com/datasets/pes12017000148/food-ingredients-and-recipe-dataset-with-images

### Code License
The processing scripts in this directory are part of the CookCut project and follow the project's licensing terms. 