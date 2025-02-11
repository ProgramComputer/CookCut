require('dotenv').config();
const axios = require('axios');

let OPENSHOT_API_URL = process.env.OPENSHOT_API_URL;
const OPENSHOT_API_TOKEN = process.env.OPENSHOT_API_TOKEN;

// Ensure URL has protocol
if (OPENSHOT_API_URL && !OPENSHOT_API_URL.startsWith('http')) {
    OPENSHOT_API_URL = `http://${OPENSHOT_API_URL}`;
}

console.log('Using OpenShot API URL:', OPENSHOT_API_URL);

async function checkProject(projectId) {
    try {
        // Get project details
        const projectResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        });
        
        const project = projectResponse.data;
        console.log('\nProject Details:');
        console.log(`ID: ${project.id}`);
        console.log(`Name: ${project.name}`);
        console.log(`Created: ${new Date(project.date_created).toLocaleString()}`);
        console.log(`Files: ${project.files.length}`);
        console.log(`Clips: ${project.clips.length}`);
        console.log(`Exports: ${project.exports.length}`);
        
        // Get project exports
        const exportsResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/exports/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        });
        
        console.log('\nExports:');
        if (Array.isArray(exportsResponse.data)) {
            exportsResponse.data.forEach(export_ => {
                console.log(`Export ID: ${export_.id}`);
                console.log(`Status: ${export_.status}`);
                console.log(`Progress: ${export_.progress}%`);
                console.log(`URL: ${export_.url}`);
                console.log('---');
            });
        }
        
        // Get project files
        const filesResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/files/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        });
        
        console.log('\nFiles:');
        if (Array.isArray(filesResponse.data)) {
            filesResponse.data.forEach(file => {
                console.log(`File ID: ${file.id}`);
                console.log(`Name: ${file.name}`);
                console.log(`URL: ${file.url}`);
                console.log('---');
            });
        }
        
        // Get project clips
        const clipsResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/clips/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        });
        
        console.log('\nClips:');
        if (Array.isArray(clipsResponse.data)) {
            clipsResponse.data.forEach(clip => {
                console.log(`Clip ID: ${clip.id}`);
                console.log(`Position: ${clip.position}`);
                console.log(`Start: ${clip.start}`);
                console.log(`End: ${clip.end}`);
                console.log('---');
            });
        }
        
    } catch (error) {
        if (error.response?.status === 404) {
            console.log(`Project ${projectId} not found`);
        } else {
            console.error('Error checking project:', error.response?.data || error.message);
            if (error.response) {
                console.error('Response status:', error.response.status);
                console.error('Response data:', JSON.stringify(error.response.data, null, 2));
                console.error('Request URL:', error.config.url);
            }
        }
    }
}

// Check project ID 178 (from your logs)
checkProject(178); 