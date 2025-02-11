require('dotenv').config();
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const FormData = require('form-data');

let OPENSHOT_API_URL = process.env.OPENSHOT_API_URL;
const OPENSHOT_API_TOKEN = process.env.OPENSHOT_API_TOKEN;

// Ensure URL has protocol
if (OPENSHOT_API_URL && !OPENSHOT_API_URL.startsWith('http')) {
    OPENSHOT_API_URL = `http://${OPENSHOT_API_URL}`;
}

console.log('Using OpenShot API URL:', OPENSHOT_API_URL);

async function waitForFile(fileUrl) {
    console.log('Waiting for file to be ready...');
    let attempts = 0;
    const maxAttempts = 30; // 1 minute max wait
    
    while (attempts < maxAttempts) {
        const response = await axios.get(fileUrl, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        });
        
        // Check if file has duration in json field, which indicates it's ready
        try {
            const jsonData = typeof response.data.json === 'string' 
                ? JSON.parse(response.data.json) 
                : response.data.json || {};
            
            if (jsonData.duration) {
                console.log(`File ready. Duration: ${jsonData.duration} seconds`);
                return jsonData.duration;
            }
        } catch (e) {
            console.log('Waiting for file processing...', e.message);
        }
        
        attempts++;
        await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
    }
    
    throw new Error('Timeout waiting for file to be ready');
}

async function isExportCompleted(exportUrl) {
    const response = await axios.get(exportUrl, {
        headers: {
            'Authorization': `Token ${OPENSHOT_API_TOKEN}`
        }
    });
    
    const exportData = response.data;
    const status = exportData.status;
    const progress = exportData.progress || 0;
    console.log(`Export progress: ${progress}%, Status: ${status}`);
    
    if (status === 'completed') {
        console.log('Export completed!');
        console.log('Output URL:', exportData.output);
        return exportData.output;
    } else if (status === 'failed') {
        throw new Error(`Export failed: ${exportData.error || 'Unknown error'}`);
    }
    
    return null;
}

async function downloadFile(url, outputPath, shouldDownload = true) {
    console.log('Processing file...');
    
    const response = await axios({
        url,
        method: 'GET',
        responseType: shouldDownload ? 'stream' : 'arraybuffer',
        headers: {
            'Authorization': `Token ${OPENSHOT_API_TOKEN}`
        }
    });

    if (!shouldDownload) {
        const buffer = Buffer.from(response.data);
        return buffer;
    }
    
    // For debugging, log the response headers instead of the binary data
    console.log('Response headers:', response.headers);
    
    const writer = fs.createWriteStream(outputPath);
    response.data.pipe(writer);

    return new Promise((resolve, reject) => {
        writer.on('finish', () => {
            console.log(`File downloaded to: ${outputPath}`);
            resolve(outputPath);
        });
        writer.on('error', reject);
    });
}

async function testTrimming(shouldDownloadFiles = false) {
    let projectId = null;
    try {
        // 1. Create a project
        console.log('\nCreating project...');
        const projectResponse = await axios.post(`${OPENSHOT_API_URL}/projects/`, {
            name: `trim_test_${Date.now()}`,
            width: 1920,
            height: 1080,
            fps_num: 30,
            fps_den: 1,
            sample_rate: 44100,
            channels: 2,
            channel_layout: 3,
            json: JSON.stringify({})
        }, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });

        projectId = projectResponse.data.id;
        const projectUrl = projectResponse.data.url;
        const exportsUrl = projectResponse.data.actions.find(url => url.endsWith('/exports/'));
        console.log('Project created:', projectId);
        console.log('Project URL:', projectUrl);
        console.log('Exports URL:', exportsUrl);
        console.log('Project response:', JSON.stringify(projectResponse.data, null, 2));

        // 2. Import the video directly from URL
        console.log('\nImporting video from URL...');
        const videoUrl = 'https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4';
        const videoBuffer = await downloadFile(videoUrl, null, false);

        const formData = new FormData();
        formData.append('media', videoBuffer, {
            filename: 'input.mp4',
            contentType: 'video/mp4'
        });
        formData.append('project', projectUrl);
        formData.append('json', JSON.stringify({}));

        const fileResponse = await axios.post(
            `${OPENSHOT_API_URL}/projects/${projectId}/files/`,
            formData,
            {
                headers: {
                    'Authorization': `Token ${OPENSHOT_API_TOKEN}`,
                    ...formData.getHeaders()
                }
            }
        );

        const fileId = fileResponse.data.id;
        const fileUrl = fileResponse.data.url;
        console.log('File imported:', fileId);

        // Wait for file to be ready and get its duration
        const duration = await waitForFile(fileUrl);
        console.log(`Total video duration: ${duration} seconds`);

        // Validate trim points
        const startTime = 6.0;
        const endTime = Math.min(22.0, duration);
        
        // 3. Create a clip with trim points
        console.log('\nCreating trimmed clip...');
        const clipResponse = await axios.post(`${OPENSHOT_API_URL}/projects/${projectId}/clips/`, {
            file: fileUrl,
            file_id: fileId,
            position: 0,
            start: startTime,
            end: endTime,
            layer: 0,
            project: projectUrl,
            json: JSON.stringify({})
        }, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });

        const clipId = clipResponse.data.id;
        console.log('Clip created:', clipId);

        // Update project JSON with the clip
        const projectJson = {
            timeline: {
                width: 1920,
                height: 1080,
                fps_num: 30,
                fps_den: 1,
                sample_rate: 44100,
                channels: 2,
                channel_layout: 3,
                layers: [
                    {
                        number: 0,
                        y: 0,
                        label: "",
                        lock: false,
                        clips: [
                            {
                                id: clipId,
                                position: 0,
                                start: startTime,
                                end: endTime,
                                layer: 0,
                                file_id: fileId,
                                title: "",
                                effects: [],
                                properties: {
                                    gravity: "center",
                                    scale: {
                                        Points: [{"co": {"Y": 1, "X": 1}, "interpolation": 2}]
                                    },
                                    location_x: {
                                        Points: [{"co": {"Y": 0, "X": 1}, "interpolation": 2}]
                                    },
                                    location_y: {
                                        Points: [{"co": {"Y": 0, "X": 1}, "interpolation": 2}]
                                    }
                                }
                            }
                        ]
                    }
                ]
            }
        };

        console.log('\nUpdating project JSON...');
        await axios.put(projectUrl, { json: projectJson }, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });

        console.log('\nChecking project details before export...');
        const projectDetailsResponse = await axios.get(projectUrl, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`
            }
        });
        console.log('Project details:', JSON.stringify(projectDetailsResponse.data, null, 2));

        // Try project validation
        console.log('\nValidating project...');
        const validateUrl = projectResponse.data.actions.find(url => url.endsWith('/validate/'));
        try {
            const validateResponse = await axios.get(validateUrl, {
                headers: {
                    'Authorization': `Token ${OPENSHOT_API_TOKEN}`
                }
            });
            console.log('Validation response:', validateResponse.data);
        } catch (error) {
            console.error('Validation failed:', error.message);
            if (error.response) {
                console.error('Validation response:', error.response.data);
            }
        }

        // Try project download
        console.log('\nTrying project download...');
        const downloadUrl = projectResponse.data.actions.find(url => url.endsWith('/download/'));
        try {
            const downloadResponse = await axios.get(downloadUrl, {
                headers: {
                    'Authorization': `Token ${OPENSHOT_API_TOKEN}`,
                    'Accept': 'application/json'  // Request JSON response if available
                }
            });
            console.log('Download headers:', downloadResponse.headers);
            console.log('Download URL:', downloadResponse.headers.location || downloadResponse.headers['content-location'] || 'Not available');
        } catch (error) {
            console.error('Download failed:', error.message);
            if (error.response) {
                console.error('Download error status:', error.response.status);
                console.error('Download error headers:', error.response.headers);
            }
        }

        // 4. Export the trimmed video
        console.log('\nStarting export...');
        const fps = 30; // fps_num/fps_den from project settings
        const startFrame = Math.floor(startTime * fps) + 1;
        const endFrame = Math.floor(endTime * fps);
        const exportBody = {
            video_format: 'mp4',
            video_codec: 'libx264',
            video_bitrate: 8000000,
            audio_codec: 'aac',
            audio_bitrate: 192000,
            start_frame: startFrame,
            end_frame: endFrame,
            width: 1920,
            height: 1080,
            fps_num: 30,
            fps_den: 1,
            max_attempts: 5,
            project: projectUrl,
            json: projectJson
        };
        console.log('Export request body:', JSON.stringify(exportBody, null, 2));
        const exportResponse = await axios.post(`${OPENSHOT_API_URL}/projects/${projectId}/exports/`, exportBody, {
            headers: {
                'Authorization': `Token ${OPENSHOT_API_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });

        const exportUrl = exportResponse.data.url;
        const exportId = exportResponse.data.id;
        console.log('Export created:', exportId);
        console.log('Export URL:', exportUrl);

        // 5. Poll for export completion (40 minutes timeout as per documentation)
        console.log('\nWaiting for export to complete...');
        let outputUrl = null;
        let attempts = 0;
        const maxAttempts = 480; // 40 minutes (5 second intervals)

        while (attempts < maxAttempts) {
            try {
                const statusResponse = await axios.get(exportUrl, {
                    headers: {
                        'Authorization': `Token ${OPENSHOT_API_TOKEN}`
                    }
                });
                
                const status = statusResponse.data.status;
                const progress = statusResponse.data.progress || 0;
                console.log(`Export progress: ${progress}%, Status: ${status}`);
                
                if (status === 'completed') {
                    console.log('Export completed!');
                    outputUrl = statusResponse.data.output;
                    console.log('Output URL:', outputUrl);
                    break;
                } else if (status === 'failed') {
                    throw new Error(`Export failed: ${statusResponse.data.error || 'Unknown error'}`);
                }
            } catch (error) {
                console.error('Export check failed:', error.message);
                break;
            }
            
            await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds
            attempts++;
        }

        if (!outputUrl) {
            throw new Error('Export timed out or failed');
        }

        // Download the exported file only if requested
        if (shouldDownloadFiles) {
            console.log('\nDownloading exported file...');
            const outputPath = path.join(__dirname, `output-${projectId}.mp4`);
            await downloadFile(outputUrl, outputPath, true);
            console.log('Export downloaded to:', outputPath);
        } else {
            console.log('\nTrimmed video URL:', outputUrl);
            return outputUrl;
        }

    } catch (error) {
        console.error('Error:', error.message);
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', JSON.stringify(error.response.data, null, 2));
            console.error('Request URL:', error.config.url);
        }
    } finally {
        // Cleanup: Delete the project as recommended by documentation
        if (projectId) {
            try {
                console.log('\nCleaning up project...');
                await axios.delete(`${OPENSHOT_API_URL}/projects/${projectId}/`, {
                    headers: {
                        'Authorization': `Token ${OPENSHOT_API_TOKEN}`
                    }
                });
                console.log('Project deleted successfully');
            } catch (error) {
                console.error('Failed to delete project:', error.message);
            }
        }
    }
}

// Only download files if running directly
if (require.main === module) {
    testTrimming(true);
} else {
    module.exports = {
        testTrimming
    };
}