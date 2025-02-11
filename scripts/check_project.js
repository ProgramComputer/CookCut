require('dotenv').config();
const axios = require('axios');

let OPENSHOT_API_URL = process.env.OPENSHOT_API_URL;
const OPENSHOT_API_TOKEN = process.env.OPENSHOT_API_TOKEN;

// Ensure URL has protocol
if (OPENSHOT_API_URL && !OPENSHOT_API_URL.startsWith('http')) {
    OPENSHOT_API_URL = `http://${OPENSHOT_API_URL}`;
}

console.log('Using OpenShot API URL:', OPENSHOT_API_URL);
console.log('Token available:', !!OPENSHOT_API_TOKEN);

async function checkExistingProject() {
    try {
        const projectId = 178; // From your logs
        console.log(`\nChecking project ${projectId}...`);
        console.log(`Request URL: ${OPENSHOT_API_URL}/projects/${projectId}/`);
        
        // Get project details
        const projectResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        }).catch(error => {
            console.error('Project request failed:', error.message);
            if (error.response) {
                console.error('Response status:', error.response.status);
                console.error('Response data:', JSON.stringify(error.response.data, null, 2));
            }
            throw error;
        });
        
        const project = projectResponse.data;
        console.log('Project details:');
        console.log(`Name: ${project.name}`);
        console.log(`Created: ${new Date(project.date_created).toLocaleString()}`);
        
        // Get files in the project
        console.log('\nGetting project files...');
        const filesResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/files/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        }).catch(error => {
            console.error('Files request failed:', error.message);
            if (error.response) {
                console.error('Response status:', error.response.status);
                console.error('Response data:', JSON.stringify(error.response.data, null, 2));
            }
            throw error;
        });
        
        console.log('\nFiles:');
        if (filesResponse.data.results && Array.isArray(filesResponse.data.results)) {
            console.log(`Total files: ${filesResponse.data.count}`);
            filesResponse.data.results.forEach(file => {
                console.log(`\nFile ID: ${file.id}`);
                console.log(`Name: ${file.media ? file.media.split('/').pop() : 'Unnamed'}`);
                console.log(`URL: ${file.url}`);
                console.log(`Media URL: ${file.media || 'None'}`);
                try {
                    const jsonData = typeof file.json === 'string' ? JSON.parse(file.json) : file.json;
                    console.log('JSON data:', JSON.stringify(jsonData, null, 2));
                } catch (e) {
                    console.log('Raw JSON:', file.json);
                }
            });
        } else {
            console.log('No files found or invalid response:', filesResponse.data);
        }
        
        // Get clips in the project
        console.log('\nGetting project clips...');
        const clipsResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/clips/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        }).catch(error => {
            console.error('Clips request failed:', error.message);
            if (error.response) {
                console.error('Response status:', error.response.status);
                console.error('Response data:', JSON.stringify(error.response.data, null, 2));
            }
            throw error;
        });
        
        console.log('\nClips:');
        if (clipsResponse.data.results && Array.isArray(clipsResponse.data.results)) {
            console.log(`Total clips: ${clipsResponse.data.count}`);
            clipsResponse.data.results.forEach(clip => {
                console.log(`\nClip ID: ${clip.id}`);
                console.log(`Position: ${clip.position}`);
                console.log(`Start: ${clip.start}`);
                console.log(`End: ${clip.end}`);
                console.log(`Layer: ${clip.layer}`);
                try {
                    const jsonData = typeof clip.json === 'string' ? JSON.parse(clip.json) : clip.json;
                    console.log('JSON data:', JSON.stringify(jsonData, null, 2));
                } catch (e) {
                    console.log('Raw JSON:', clip.json);
                }
            });
        } else {
            console.log('No clips found or invalid response:', clipsResponse.data);
        }
        
        // Get exports in the project
        console.log('\nGetting project exports...');
        const exportsResponse = await axios.get(`${OPENSHOT_API_URL}/projects/${projectId}/exports/`, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        }).catch(error => {
            console.error('Exports request failed:', error.message);
            if (error.response) {
                console.error('Response status:', error.response.status);
                console.error('Response data:', JSON.stringify(error.response.data, null, 2));
            }
            throw error;
        });
        
        console.log('\nExports:');
        if (exportsResponse.data.results && Array.isArray(exportsResponse.data.results)) {
            console.log(`Total exports: ${exportsResponse.data.count}`);
            exportsResponse.data.results.forEach(export_ => {
                console.log(`\nExport ID: ${export_.id}`);
                console.log(`Status: ${export_.status}`);
                console.log(`Progress: ${export_.progress}%`);
                if (export_.output) {
                    console.log(`Output: ${export_.output}`);
                }
                if (export_.error) {
                    console.log(`Error: ${export_.error}`);
                }
                try {
                    const jsonData = typeof export_.json === 'string' ? JSON.parse(export_.json) : export_.json;
                    console.log('JSON data:', JSON.stringify(jsonData, null, 2));
                } catch (e) {
                    console.log('Raw JSON:', export_.json);
                }
            });
        } else {
            console.log('No exports found or invalid response:', exportsResponse.data);
        }
        
    } catch (error) {
        console.error('Error:', error.message);
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', JSON.stringify(error.response.data, null, 2));
            console.error('Request URL:', error.config.url);
            if (error.config.data) {
                console.error('Request data:', error.config.data);
            }
        }
        process.exit(1);
    }
}

checkExistingProject(); 