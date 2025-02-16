require('dotenv').config();
const axios = require('axios');

const REPLICATE_API_TOKEN = process.env.REPLICATE_API_KEY;
const KLING_MODEL = "kwaivgi/kling-v1.6-standard";

async function generateVideo() {
    console.log('Starting video generation test...');
    
    try {
        // Create prediction
        const response = await axios.post(
            `https://api.replicate.com/v1/models/${KLING_MODEL}/predictions`,
            {
                input: {
                    prompt: "Professional chef preparing a gourmet meal in a modern kitchen",
                    duration: 5,
                    cfg_scale: 0.5,
                    aspect_ratio: "16:9",
                    negative_prompt: "blurry, low quality, distorted, ugly, poorly made"
                }
            },
            {
                headers: {
                    'Authorization': `Token ${REPLICATE_API_TOKEN}`,
                    'Content-Type': 'application/json',
                }
            }
        );

        console.log('Prediction created:', response.data);
        const predictionId = response.data.id;

        // Poll for results
        console.log('Polling for results...');
        let completed = false;
        while (!completed) {
            const statusResponse = await axios.get(
                `https://api.replicate.com/v1/predictions/${predictionId}`,
                {
                    headers: {
                        'Authorization': `Token ${REPLICATE_API_TOKEN}`,
                    }
                }
            );

            const prediction = statusResponse.data;
            console.log('Status:', prediction.status);
            
            if (prediction.status === 'succeeded') {
                console.log('Generation completed!');
                console.log('Output URL:', prediction.output);
                completed = true;
            } else if (prediction.status === 'failed') {
                console.error('Generation failed:', prediction.error);
                completed = true;
            } else {
                // Wait 5 seconds before checking again
                await new Promise(resolve => setTimeout(resolve, 5000));
            }
        }
    } catch (error) {
        console.error('Error:', error.response?.data || error.message);
        if (error.response?.status === 429) {
            console.error('Rate limit exceeded. Please try again later.');
        }
    }
}

generateVideo(); 