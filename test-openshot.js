require('dotenv').config();
const axios = require('axios');

const OPENSHOT_API_URL = process.env.OPENSHOT_API_URL;
const OPENSHOT_API_TOKEN = process.env.OPENSHOT_API_TOKEN;

if (!OPENSHOT_API_URL || !OPENSHOT_API_TOKEN) {
    console.error('Missing required environment variables. Please check your .env file.');
    process.exit(1);
}

async function testOpenShotConnection() {
    try {
        console.log('Testing OpenShot API connection...');
        console.log(`API URL: ${OPENSHOT_API_URL}`);
        
        // First test basic connectivity with info endpoint
        console.log('\nTesting API info endpoint...');
        const infoResponse = await axios.get(`${OPENSHOT_API_URL}/info`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        });
        
        if (infoResponse.status === 200) {
            console.log('Successfully connected to OpenShot API');
            console.log('API Version:', infoResponse.data.version);
            console.log('API Debug Mode:', infoResponse.data.debug);
        }
        
        // Test project creation
        console.log('\nTesting project creation...');
        const projectResponse = await axios.post(`${OPENSHOT_API_URL}/projects/`, {
            name: 'Test_Project_' + Date.now(),
            width: 1920,
            height: 1080,
            fps_num: 30,
            fps_den: 1,
            sample_rate: 44100,
            channels: 2,
            channel_layout: 3,
            json: JSON.stringify({
                duration: 0,
                scale: 15,
                tick_pixels: 100,
                playhead_position: 0
            })
        }, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });

        if (projectResponse.status === 201) {
            console.log('Project creation successful');
            console.log('Project details:', projectResponse.data);

            const projectId = projectResponse.data.id;
            console.log('Project created with ID:', projectId);

            // Test project deletion
            console.log('\nTesting project deletion...');
            const deleteResponse = await axios.delete(`${OPENSHOT_API_URL}/projects/${projectId}/`, {
                headers: {
                    'Authorization': `Token ${OPENSHOT_API_TOKEN}`
                }
            });
            
            if (deleteResponse.status === 204) {
                console.log('Project deleted successfully');
            }
        }

    } catch (error) {
        console.error('Error testing OpenShot connection:');
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', error.response.data);
            console.error('Request URL:', error.config.url);
            console.error('Request method:', error.config.method);
            console.error('Request headers:', JSON.stringify(error.config.headers, null, 2));
            if (error.config.data) {
                console.error('Request data:', error.config.data);
            }
        } else if (error.request) {
            console.error('No response received');
            console.error('Request details:', error.request);
        } else {
            console.error('Error details:', error.message);
        }
        process.exit(1);
    }
}

testOpenShotConnection();
