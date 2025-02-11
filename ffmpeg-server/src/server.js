const express = require('express');
const { spawn } = require('child_process');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

// Supabase client initialization
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

// Generate a secure API key if none is provided
function generateSecureApiKey() {
    return crypto.randomBytes(32).toString('hex');
}

// API key configuration - only generate if not provided in .env
let API_KEY = process.env.FFMPEG_API_KEY;

if (!API_KEY) {
    const generatedKey = generateSecureApiKey();
    console.log('\n');
    console.log('*'.repeat(60));
    console.log('FFmpeg Server API Key Configuration');
    console.log('*'.repeat(60));
    console.log('\nNo API Key found in .env, generated new key:');
    console.log('FFMPEG_API_KEY=' + generatedKey);
    console.log('\nIMPORTANT: Add this key to your .env file');
    console.log('\n' + '*'.repeat(60) + '\n');
    API_KEY = generatedKey;
} else {
    console.log('Using API Key from .env file');
}

const app = express();
app.use(express.json({ 
    limit: '50mb',
    timeout: 300000 // 5 minutes
}));
app.use(cors({
    maxAge: 86400 // 24 hours CORS cache
}));

// API key validation middleware
const validateApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'] || req.query.api_key;
    
    console.log('Received request with API key:', apiKey ? 'Present' : 'Missing');
    
    if (!apiKey || apiKey !== API_KEY) {
        console.warn('Invalid or missing API key from:', req.ip);
        return res.status(401).json({ 
            error: 'Unauthorized: Invalid or missing API key',
            requestId: uuidv4() // Add request ID for tracking
        });
    }
    next();
};

// Apply API key validation to all routes except health check
app.use((req, res, next) => {
    if (req.path === '/health') {
        return next();
    }
    validateApiKey(req, res, next);
});

// Add an endpoint to verify API key
app.get('/verify-key', (req, res) => {
    const apiKey = req.headers['x-api-key'] || req.query.api_key;
    if (apiKey === API_KEY) {
        res.json({ status: 'valid', message: 'API key is valid' });
    } else {
        res.status(401).json({ status: 'invalid', message: 'Invalid API key' });
    }
});

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: '/tmp/ffmpeg/uploads',
    filename: (req, file, cb) => {
        cb(null, `${Date.now()}-${file.originalname}`);
    }
});
const upload = multer({ storage: storage });

// Ensure directories exist
fs.mkdirSync('/tmp/ffmpeg/uploads', { recursive: true });
fs.mkdirSync('/tmp/ffmpeg/output', { recursive: true });

// Helper function to update job status
async function updateJobStatus(jobId, data) {
    try {
        const { error } = await supabase
            .from('video_jobs')
            .update({
                ...data,
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId);

        if (error) throw error;
    } catch (err) {
        console.error('Error updating job status:', err);
    }
}

// Get video duration using FFprobe
async function getVideoDuration(filePath) {
    return new Promise((resolve, reject) => {
        const ffprobe = spawn('ffprobe', [
            '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            filePath
        ]);

        let duration = '';
        ffprobe.stdout.on('data', (data) => {
            duration += data.toString();
        });

        ffprobe.stderr.on('data', (data) => {
            console.error('FFprobe error:', data.toString());
        });

        ffprobe.on('close', (code) => {
            if (code === 0) {
                resolve(parseFloat(duration.trim()));
            } else {
                reject(new Error('Failed to get video duration'));
            }
        });
    });
}

// Cleanup old files (older than 1 hour)
function cleanupOldFiles() {
    const oneHourAgo = Date.now() - (60 * 60 * 1000);
    
    ['uploads', 'output'].forEach(dir => {
        const dirPath = `/tmp/ffmpeg/${dir}`;
        fs.readdir(dirPath, (err, files) => {
            if (err) return;
            files.forEach(file => {
                const filePath = path.join(dirPath, file);
                fs.stat(filePath, (err, stats) => {
                    if (err) return;
                    if (stats.mtimeMs < oneHourAgo) {
                        fs.unlink(filePath, () => {});
                    }
                });
            });
        });
    });
}

// Run cleanup every 15 minutes
setInterval(cleanupOldFiles, 15 * 60 * 1000);

// Basic health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

// Helper function to upload to Supabase
async function uploadToSupabase(filePath, fileName, projectId) {
    if (!projectId) {
        throw new Error('Project ID is required for uploading processed videos');
    }

    try {
        const fileBuffer = fs.readFileSync(filePath);
        const { data, error } = await supabase
            .storage
            .from('cookcut-media')
            .upload(`${projectId}/media/edited/${fileName}`, fileBuffer, {
                contentType: 'video/mp4',
                upsert: true
            });

        if (error) throw error;

        // Get public URL
        const { data: { publicUrl } } = supabase
            .storage
            .from('cookcut-media')
            .getPublicUrl(`${projectId}/media/edited/${fileName}`);

        return publicUrl;
    } catch (error) {
        console.error('Supabase upload error:', error);
        throw error;
    }
}

// File upload and process
app.post('/upload-and-process', upload.single('video'), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No video file uploaded' });
    }

    const inputPath = req.file.path;
    const outputPath = `/tmp/ffmpeg/output/${Date.now()}-output${path.extname(req.file.originalname)}`;
    const command = req.body.command.replace('input.mp4', inputPath).replace('output.mp4', outputPath);

    // Validate FFmpeg command
    if (!command.startsWith('ffmpeg ')) {
        fs.unlink(inputPath, () => {});
        return res.status(400).json({ error: 'Invalid FFmpeg command' });
    }

    // Get video duration for accurate progress calculation
    let duration;
    try {
        duration = await getVideoDuration(inputPath);
        console.log(`Video duration: ${duration} seconds`);
    } catch (err) {
        console.error('Error getting video duration:', err);
        duration = 0; // Fallback to indeterminate progress
    }

    const jobId = uuidv4();
    await updateJobStatus(jobId, { 
        status: 'starting',
        progress: 0,
        startTime: Date.now(),
        duration: duration
    });

    console.log(`Processing job ${jobId}: ${command}`);

    // Use spawn instead of exec to get progress
    const args = command.split(' ').slice(1);
    const ffmpeg = spawn('ffmpeg', args);
    
    let error = '';

    ffmpeg.stderr.on('data', (data) => {
        const output = data.toString();
        error += output;

        // Parse progress
        const timeMatch = output.match(/time=(\d+:\d+:\d+.\d+)/);
        if (timeMatch) {
            const time = timeMatch[1];
            const [hours, minutes, seconds] = time.split(':').map(parseFloat);
            const currentSeconds = (hours * 3600) + (minutes * 60) + seconds;
            
            // Update job progress
            updateJobStatus(jobId, { progress: Math.min(99, (currentSeconds / duration) * 100) });
        }
    });

    ffmpeg.on('close', async (code) => {
        // Clean up input file
        fs.unlink(inputPath, (err) => {
            if (err) console.error('Error deleting input file:', err);
        });

        if (code === 0) {
            await updateJobStatus(jobId, { 
                status: 'complete',
                progress: 100,
                outputPath: outputPath,
                error: error
            });
        } else {
            await updateJobStatus(jobId, { 
                status: 'failed',
                error: error
            });
            // Clean up output file if failed
            fs.unlink(outputPath, () => {});
        }
    });

    res.json({ jobId, status: 'processing' });
});

// Modify the process-url endpoint to use Supabase
app.post('/process-url', express.json(), async (req, res) => {
    const { videoUrl, command, projectId } = req.body;
    
    console.log('Received process-url request:', {
        videoUrl,
        command,
        projectId,
        headers: req.headers
    });
    
    if (!videoUrl || !command || !projectId) {
        return res.status(400).json({ error: 'Video URL, FFmpeg command, and project ID are required' });
    }

    // Validate FFmpeg command
    if (!command.startsWith('ffmpeg ')) {
        return res.status(400).json({ error: 'Invalid FFmpeg command' });
    }

    // Create new job in Supabase
    const { data: job, error: createError } = await supabase
        .from('video_jobs')
        .insert({
            status: 'processing',
            progress: 0,
            input_url: videoUrl,
            project_id: projectId
        })
        .select()
        .single();

    if (createError) {
        console.error('Error creating job:', createError);
        return res.status(500).json({ error: 'Failed to create job' });
    }

    const jobId = job.id;
    const outputFileName = `${Date.now()}-${jobId}.mp4`;
    const outputPath = `/tmp/ffmpeg/output/${outputFileName}`;
    
    console.log(`Job ${jobId} initialized:`, {
        outputPath,
        startTime: new Date().toISOString()
    });

    // Parse the FFmpeg command
    const parsedCommand = command
        .replace('input.mp4', 'pipe:0')
        .replace('output.mp4', outputPath);
    
    console.log(`Processing job ${jobId} with command: ${parsedCommand}`);

    // Start FFmpeg process
    const args = parsedCommand.split(' ').slice(1);
    const ffmpeg = spawn('ffmpeg', args);
    
    let error = '';

    ffmpeg.stdin.on('error', async (err) => {
        console.error(`FFmpeg stdin error for job ${jobId}:`, err);
        if (err.code !== 'EPIPE') {
            console.error('FFmpeg input error:', err);
            await updateJobStatus(jobId, {
                status: 'failed',
                error: `Stream error: ${err.message}`
            });
        }
    });

    // Handle client disconnect
    req.on('close', () => {
        console.log(`Client disconnected for job ${jobId}`);
    });

    // Download and process video
    const request = videoUrl.startsWith('https') ? https : http;
    console.log(`Starting video download for job ${jobId} from URL: ${videoUrl}`);
    
    const videoRequest = request.get(videoUrl, {
        timeout: 30000,
        headers: {
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive'
        }
    }, (response) => {
        console.log(`Download response received for job ${jobId}:`, {
            statusCode: response.statusCode,
            headers: response.headers
        });
        
        if (response.statusCode !== 200) {
            const error = `Failed to fetch video: ${response.statusCode}`;
            console.error(`Job ${jobId} failed:`, error);
            updateJobStatus(jobId, {
                status: 'failed',
                error
            });
            return;
        }

        const contentLength = parseInt(response.headers['content-length'], 10);
        let bytesReceived = 0;

        response.on('data', (chunk) => {
            bytesReceived += chunk.length;
            const progress = contentLength ? 
                Math.min(50, Math.floor((bytesReceived / contentLength) * 50)) : // Use first 50% for download
                Math.min(50, Math.floor((bytesReceived / 1000000))); // Estimate if no content length

            updateJobStatus(jobId, { progress });

            // Handle backpressure
            const canContinue = ffmpeg.stdin.write(chunk);
            if (!canContinue) {
                response.pause();
                ffmpeg.stdin.once('drain', () => {
                    response.resume();
                });
            }
        });

        response.on('end', () => {
            console.log(`Download complete for job ${jobId}`);
            ffmpeg.stdin.end();
        });

        response.on('error', async (err) => {
            console.error(`Response error for job ${jobId}:`, err);
            await updateJobStatus(jobId, {
                status: 'failed',
                error: `Download error: ${err.message}`
            });
            ffmpeg.kill();
        });
    });

    videoRequest.setTimeout(30000, () => {
        console.error(`Request timeout for job ${jobId}`);
        videoRequest.destroy();
        updateJobStatus(jobId, {
            status: 'failed',
            error: 'Request timeout after 30 seconds'
        });
        ffmpeg.kill();
    });

    ffmpeg.stderr.on('data', (data) => {
        const output = data.toString();
        error += output;
        console.log(`FFmpeg output for job ${jobId}: ${output}`);
        
        // Parse progress from FFmpeg output
        const timeMatch = output.match(/time=(\d+:\d+:\d+.\d+)/);
        if (timeMatch) {
            const time = timeMatch[1];
            const [hours, minutes, seconds] = time.split(':').map(parseFloat);
            const currentSeconds = (hours * 3600) + (minutes * 60) + seconds;
            
            // Use second 50% for processing progress
            const processingProgress = Math.min(50, Math.floor((currentSeconds / 30) * 50)) + 50;
            updateJobStatus(jobId, { progress: processingProgress });
        }
    });

    ffmpeg.on('close', async (code) => {
        console.log(`FFmpeg process closed for job ${jobId} with code ${code}`);
        if (code === 0 && fs.existsSync(outputPath)) {
            try {
                // Upload to Supabase storage
                const publicUrl = await uploadToSupabase(outputPath, outputFileName, projectId);
                
                await updateJobStatus(jobId, {
                    status: 'complete',
                    progress: 100,
                    output_url: publicUrl
                });

                // Clean up local file
                fs.unlink(outputPath, (err) => {
                    if (err) console.error('Error deleting output file:', err);
                });
            } catch (uploadError) {
                console.error('Upload error:', uploadError);
                await updateJobStatus(jobId, {
                    status: 'failed',
                    error: `Upload failed: ${uploadError.message}`
                });
            }
        } else {
            await updateJobStatus(jobId, {
                status: 'failed',
                error: error || 'FFmpeg process failed'
            });
            // Clean up output file if failed
            fs.unlink(outputPath, () => {});
        }
    });

    res.json({ jobId, status: 'processing' });
});

// Get processed file
app.get('/output/:jobId', async (req, res) => {
    // Get job from Supabase
    const { data: jobStatus, error } = await supabase
        .from('video_jobs')
        .select('output_url')
        .eq('id', req.params.jobId)
        .single();

    if (error || !jobStatus || !jobStatus.output_url) {
        return res.status(404).json({ error: 'Output file not found' });
    }

    // Redirect to the Supabase storage URL
    res.redirect(jobStatus.output_url);
});

const port = 3000;
app.listen(port, () => {
    console.log(`FFmpeg server running on port ${port}`);
}); 