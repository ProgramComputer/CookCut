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
const OpenAI = require('openai');
const openai = new OpenAI();
const os = require('os');
const { OpenAI: LangChainOpenAI } = require('@langchain/openai');
const { ChatOpenAI } = require('@langchain/openai');
const { StringOutputParser } = require('langchain/schema/output_parser');
const { RunnableSequence } = require('langchain/schema/runnable');
const { LangChainTracer, ConsoleCallbackHandler } = require('langchain/callbacks');
const { Client } = require('langsmith');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

// Add Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'FFmpeg Server API',
      version: '1.0.0',
      description: 'API documentation for FFmpeg Server with video processing and recipe analysis capabilities',
    },
    servers: [
      {
        url: process.env.NODE_ENV === 'production' 
          ? 'https://ec2-52-10-62-41.us-west-2.compute.amazonaws.com'
          : 'http://localhost:3000',
        description: process.env.NODE_ENV === 'production' ? 'Production server' : 'Development server',
      },
    ],
    components: {
      securitySchemes: {
        ApiKeyAuth: {
          type: 'apiKey',
          in: 'header',
          name: 'x-api-key',
          description: 'API key for authentication',
        },
      },
    },
    security: [
      {
        ApiKeyAuth: [],
      },
    ],
  },
  apis: ['./src/server.js'], // Path to the API docs
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Supabase client initialization
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

// Initialize LangChain tracing
let tracer;
if (process.env.LANGCHAIN_TRACING_V2 === 'true' && 
    process.env.LANGCHAIN_ENDPOINT && 
    process.env.LANGCHAIN_API_KEY &&
    process.env.LANGCHAIN_PROJECT) {
    console.log('Initializing LangChain tracing...');
    const client = new Client({
        apiUrl: process.env.LANGCHAIN_ENDPOINT,
        apiKey: process.env.LANGCHAIN_API_KEY,
    });
    tracer = new LangChainTracer({
        projectName: process.env.LANGCHAIN_PROJECT,
        client
    });
    console.log('LangChain tracing initialized successfully');
} else {
    console.log('LangChain tracing disabled or missing configuration');
    tracer = new ConsoleCallbackHandler();
}

// Initialize OpenAI models with tracing
const visionModel = new ChatOpenAI({
    modelName: "gpt-4-vision-preview",
    maxTokens: 1000,
    temperature: 0.2,
    callbacks: [tracer]
});

const recipeModel = new ChatOpenAI({
    modelName: "gpt-4-1106-preview",
    temperature: 0.3,
    callbacks: [tracer]
});

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
            .upload(`media/${projectId}/processed/${fileName}`, fileBuffer, {
                contentType: 'video/mp4',
                upsert: true
            });

        if (error) throw error;

        // Get public URL
        const { data: { publicUrl } } = supabase
            .storage
            .from('cookcut-media')
            .getPublicUrl(`media/${projectId}/processed/${fileName}`);

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

// Add recipe analysis endpoint
app.post('/analyze-recipe', async (req, res) => {
  const { videoPath, projectId } = req.body;
  
  if (!videoPath || !projectId) {
    console.error('Missing required parameters:', { videoPath, projectId });
    return res.status(400).json({ 
      success: false, 
      error: 'Missing videoPath or projectId' 
    });
  }

  console.log('Starting recipe analysis for:', { videoPath, projectId });

  // Create temporary directories with random names
  const tempDir = path.join(os.tmpdir(), `recipe_${uuidv4()}`);
  const framesDir = path.join(tempDir, 'frames');
  const videoFile = path.join(tempDir, 'input.mp4');
  
  try {
    // Create temporary directories
    fs.mkdirSync(framesDir, { recursive: true });
    console.log('Created temporary directories:', { tempDir, framesDir });

    // Download video from Supabase
    console.log('Downloading video from Supabase:', videoPath);
    const { data: videoData, error: downloadError } = await supabase
      .storage
      .from('cookcut-media')
      .download(`${projectId}/media/${videoPath}`);

    if (downloadError) {
      console.error('Error downloading video:', downloadError);
      throw downloadError;
    }

    // Save video to temp file
    fs.writeFileSync(videoFile, Buffer.from(await videoData.arrayBuffer()));
    console.log('Video downloaded and saved to:', videoFile);

    // Extract frames (1 frame per second)
    console.log('Extracting frames from video...');
    await new Promise((resolve, reject) => {
      ffmpeg(videoFile)
        .outputOptions([
          '-vf', 'fps=1',  // 1 frame per second
          '-frame_pts', '1' // Include presentation timestamp
        ])
        .output(`${framesDir}/frame_%d.jpg`)
        .on('start', (command) => {
          console.log('FFmpeg command:', command);
        })
        .on('progress', (progress) => {
          console.log('Frame extraction progress:', progress);
        })
        .on('end', () => {
          console.log('Frame extraction completed');
          resolve();
        })
        .on('error', (err) => {
          console.error('Frame extraction error:', err);
          reject(err);
        })
        .run();
    });

    // Get video metadata
    console.log('Getting video metadata...');
    const metadata = await new Promise((resolve, reject) => {
      ffmpeg.ffprobe(videoFile, (err, metadata) => {
        if (err) {
          console.error('Metadata extraction error:', err);
          reject(err);
        } else {
          console.log('Video metadata:', metadata.format);
          resolve(metadata);
        }
      });
    });

    // Get all frames with their timestamps
    const frames = fs.readdirSync(framesDir)
      .filter(file => file.endsWith('.jpg'))
      .map(file => ({
        path: path.join(framesDir, file),
        timestamp: parseInt(file.split('_')[1].split('.')[0])
      }))
      .sort((a, b) => a.timestamp - b.timestamp);

    console.log(`Found ${frames.length} frames to analyze`);

    // Analyze frames in batches using LangChain
    const batchSize = 4;
    const frameBatches = chunks(frames, batchSize);
    const analyses = [];

    console.log(`Processing frames in ${frameBatches.length} batches of ${batchSize}`);

    for (const [index, batch] of frameBatches.entries()) {
      console.log(`Processing batch ${index + 1}/${frameBatches.length}`);
      
      const messages = [{
        role: "user",
        content: [
          {
            type: "text",
            text: `Analyze these ${batch.length} frames from a cooking video and for each frame:
            1. Identify ingredients visible
            2. Describe the cooking technique being used
            3. Note any important measurements or timing
            4. Identify any special equipment
            
            Format your response as a JSON array with timestamps.`
          },
          ...batch.map(frame => ({
            type: "image_url",
            image_url: `data:image/jpeg;base64,${fs.readFileSync(frame.path).toString('base64')}`
          }))
        ]
      }];

      const chain = RunnableSequence.from([
        visionModel,
        new StringOutputParser(),
        (text) => JSON.parse(text)
      ]);

      const batchAnalysis = await chain.invoke(messages);
      analyses.push(...batchAnalysis.frames);
      console.log(`Completed batch ${index + 1} analysis`);
    }

    // Compile final recipe using LangChain
    console.log('Compiling final recipe...');
    const recipeChain = RunnableSequence.from([
      recipeModel,
      new StringOutputParser(),
      (text) => JSON.parse(text)
    ]);

    const recipePrompt = [{
      role: "system",
      content: "You are a professional recipe writer. Create a well-structured recipe from the video analysis data."
    }, {
      role: "user",
      content: `Create a detailed recipe from these timestamped cooking steps. Include:
      1. Recipe title
      2. Estimated time and difficulty
      3. Ingredients list with measurements
      4. Equipment needed
      5. Step-by-step instructions with timestamps
      6. Tips and variations
      
      Video metadata: ${JSON.stringify({
        duration: metadata.format.duration,
        filename: path.basename(videoPath)
      })}
      Frame analyses: ${JSON.stringify(analyses)}`
    }];

    const compiledRecipe = await recipeChain.invoke(recipePrompt);
    console.log('Recipe compilation completed');

    // Clean up all temporary files
    console.log('Cleaning up temporary files...');
    fs.rmSync(tempDir, { recursive: true, force: true });

    // Return the analysis results
    console.log('Analysis completed successfully');
    res.json({
      success: true,
      recipe: compiledRecipe,
      frameAnalyses: analyses
    });

  } catch (error) {
    console.error('Fatal error during recipe analysis:', error);
    
    // Clean up on error
    if (fs.existsSync(tempDir)) {
      console.log('Cleaning up temporary directory after error');
      fs.rmSync(tempDir, { recursive: true, force: true });
    }

    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// Add helper function for chunking arrays
function chunks(array, size) {
  const result = [];
  for (let i = 0; i < array.length; i += size) {
    result.push(array.slice(i, i + size));
  }
  return result;
}

const port = 3000;
app.listen(port, () => {
    console.log(`FFmpeg server running on port ${port}`);
});

// Add after app initialization but before routes
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Add before health check endpoint
/**
 * @swagger
 * /health:
 *   get:
 *     summary: Check server health
 *     description: Returns server health status
 *     responses:
 *       200:
 *         description: Server is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: ok
 */

// Add before analyze-recipe endpoint
/**
 * @swagger
 * /analyze-recipe:
 *   post:
 *     summary: Analyze a cooking video and generate a recipe
 *     description: Extracts frames from a video, analyzes them using AI, and generates a detailed recipe
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - videoPath
 *               - projectId
 *             properties:
 *               videoPath:
 *                 type: string
 *                 description: Path to the video in Supabase storage
 *               projectId:
 *                 type: string
 *                 description: Project ID for storage path
 *     responses:
 *       200:
 *         description: Recipe analysis completed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 recipe:
 *                   type: object
 *                   properties:
 *                     title:
 *                       type: string
 *                     estimatedTime:
 *                       type: object
 *                       properties:
 *                         prep:
 *                           type: string
 *                         cook:
 *                           type: string
 *                         total:
 *                           type: string
 *                     difficulty:
 *                       type: string
 *                     ingredients:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           item:
 *                             type: string
 *                           amount:
 *                             type: string
 *                           unit:
 *                             type: string
 *                           notes:
 *                             type: string
 *                     equipment:
 *                       type: array
 *                       items:
 *                         type: string
 *                     steps:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           number:
 *                             type: integer
 *                           instruction:
 *                             type: string
 *                           timestamp:
 *                             type: integer
 *                           technique:
 *                             type: string
 *                           tip:
 *                             type: string
 *                     tips:
 *                       type: array
 *                       items:
 *                         type: string
 *                     variations:
 *                       type: array
 *                       items:
 *                         type: string
 *                 frameAnalyses:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       timestamp:
 *                         type: integer
 *                       ingredients:
 *                         type: array
 *                         items:
 *                           type: string
 *                       technique:
 *                         type: string
 *                       measurements:
 *                         type: string
 *                       equipment:
 *                         type: array
 *                         items:
 *                           type: string
 *       400:
 *         description: Missing required parameters
 *       401:
 *         description: Invalid or missing API key
 *       500:
 *         description: Server error
 */

// Add before upload-and-process endpoint
/**
 * @swagger
 * /upload-and-process:
 *   post:
 *     summary: Upload and process a video
 *     description: Upload a video file and process it using FFmpeg
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - video
 *               - command
 *             properties:
 *               video:
 *                 type: string
 *                 format: binary
 *                 description: Video file to process
 *               command:
 *                 type: string
 *                 description: FFmpeg command to execute
 *     responses:
 *       200:
 *         description: Processing started successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 jobId:
 *                   type: string
 *                 status:
 *                   type: string
 *       400:
 *         description: Invalid request
 *       401:
 *         description: Invalid or missing API key
 *       500:
 *         description: Server error
 */

// Add before process-url endpoint
/**
 * @swagger
 * /process-url:
 *   post:
 *     summary: Process a video from URL
 *     description: Process a video from a given URL using FFmpeg
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - videoUrl
 *               - command
 *               - projectId
 *             properties:
 *               videoUrl:
 *                 type: string
 *                 description: URL of the video to process
 *               command:
 *                 type: string
 *                 description: FFmpeg command to execute
 *               projectId:
 *                 type: string
 *                 description: Project ID for storage
 *     responses:
 *       200:
 *         description: Processing started successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 jobId:
 *                   type: string
 *                 status:
 *                   type: string
 *       400:
 *         description: Invalid request
 *       401:
 *         description: Invalid or missing API key
 *       500:
 *         description: Server error
 */ 