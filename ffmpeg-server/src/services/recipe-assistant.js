require('dotenv').config();

const { Pinecone } = require('@pinecone-database/pinecone');
const ffmpeg = require('fluent-ffmpeg');
const { HumanMessage, SystemMessage } = require('@langchain/core/messages');
const { createClient } = require('@supabase/supabase-js');
const { ChatOpenAI } = require('@langchain/openai');
const { OpenAIEmbeddings } = require('@langchain/openai');
const { StringOutputParser } = require('@langchain/core/output_parsers');
const { RunnableSequence } = require('@langchain/core/runnables');
const { CallbackManager } = require('@langchain/core/callbacks/manager');
const { ConsoleCallbackHandler } = require('@langchain/core/tracers/console');
const { LangChainTracer } = require('@langchain/core/tracers/initialize');
const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');
const FormData = require('form-data');
const { v4: uuidv4 } = require('uuid');
const { z } = require('zod');

// FFmpeg temp directories structure
const FFMPEG_DIRS = {
    base: '/tmp/ffmpeg',
    frames: '/tmp/ffmpeg/frames',
    audio: '/tmp/ffmpeg/audio',
    output: '/tmp/ffmpeg/output',
    temp: '/tmp/ffmpeg/temp'
};

// Enhanced schema definitions for structured output
const VideoCommandSchema = z.object({
    operation: z.enum(['clip', 'merge', 'trim', 'extract_audio']),
    description: z.string(),
    ffmpegCommand: z.string(),
    inputFiles: z.array(z.string()),
    outputFile: z.string(),
    expectedDuration: z.number().optional(),
    startTime: z.number().optional(),
    endTime: z.number().optional(),
    metadata: z.object({
        projectId: z.string(),
        userId: z.string().optional(),
        originalFileName: z.string().optional(),
        processingType: z.string()
    })
});

const MediaAnalysisSchema = z.object({
    id: z.string(),  // Asset ID from Supabase
    name: z.string(), // Original filename
    type: z.enum(['video', 'audio']),
    url: z.string(), // Signed URL
    analysis: z.union([
        z.object({
            frameAnalysis: z.array(z.object({
                timestamp: z.string(),
                analysis: z.string(),
                isSignificant: z.boolean()
            })),
            significantMoments: z.array(z.object({
                timestamp: z.string(),
                reason: z.string()
            }))
        }),
        z.object({
            segments: z.array(z.object({
                start: z.number(),
                end: z.number(),
                type: z.string()
            }))
        })
    ])
});

const RecipeSuggestionSchema = z.object({
    response: z.string(),
    videoCommands: z.array(VideoCommandSchema),
    mediaAnalyses: z.array(MediaAnalysisSchema),
    recipeAnalysis: z.object({
        suggestedEnhancements: z.array(z.object({
            technique: z.string(),
            reason: z.string()
        }))
    }),
    futureSuggestions: z.object({
        contentIdeas: z.array(z.object({
            suggestion: z.string()
        }))
    })
});

// Add timestamp extraction helper
const extractTimestamps = (query) => {
    const timeRegex = /(\d{1,2}):(\d{2})/g;
    const matches = [...query.matchAll(timeRegex)];
    return matches.map(match => {
        const [minutes, seconds] = match[0].split(':').map(Number);
        return minutes * 60 + seconds;
    });
};

// Setup FFmpeg working directories
const setupFFmpegDirs = async () => {
    console.log('Setting up FFmpeg directories...');
    try {
        for (const [key, dir] of Object.entries(FFMPEG_DIRS)) {
            if (!fs.existsSync(dir)) {
                await fs.promises.mkdir(dir, { recursive: true });
                console.log(`Created ${key} directory: ${dir}`);
            }
        }
        return true;
    } catch (error) {
        console.error('Error setting up FFmpeg directories:', error);
        throw new Error(`Failed to setup FFmpeg directories: ${error.message}`);
    }
};

// Validate FFmpeg command before execution
const validateFFmpegCommand = async (command) => {
    console.log('Validating FFmpeg command:', command);
    
    // Basic schema validation
    if (!VideoCommandSchema.operation.includes(command.operation)) {
        throw new Error(`Invalid operation: ${command.operation}`);
    }

    // Input file validation
    for (const inputFile of command.inputFiles) {
        if (!fs.existsSync(inputFile)) {
            throw new Error(`Input file not found: ${inputFile}`);
        }
        
        // Check file permissions
        try {
            await fs.promises.access(inputFile, fs.constants.R_OK);
        } catch (error) {
            throw new Error(`Cannot read input file: ${inputFile}`);
        }
    }

    // Output path validation
    const outputDir = path.dirname(command.outputFile);
    if (!fs.existsSync(outputDir)) {
        try {
            await fs.promises.mkdir(outputDir, { recursive: true });
        } catch (error) {
            throw new Error(`Cannot create output directory: ${outputDir}`);
        }
    }

    // Validate timestamps if present
    if (command.startTime !== undefined && command.endTime !== undefined) {
        if (command.startTime >= command.endTime) {
            throw new Error('Start time must be less than end time');
        }
        
        // Validate against source duration
        const duration = await getVideoDuration(command.inputFiles[0]);
        if (command.endTime > duration) {
            throw new Error(`End time (${command.endTime}s) exceeds video duration (${duration}s)`);
        }
    }

    // Test FFmpeg command syntax
    try {
        const dryRunCommand = `ffmpeg -hide_banner ${command.ffmpegCommand} -f null -`;
        await new Promise((resolve, reject) => {
            ffmpeg()
                .input(command.inputFiles[0])
                .outputOptions(['-f', 'null', '-'])
                .on('error', reject)
                .on('end', resolve)
                .run();
        });
    } catch (error) {
        throw new Error(`Invalid FFmpeg command syntax: ${error.message}`);
    }

    return true;
};

// Get video duration helper
const getVideoDuration = async (videoPath) => {
    return new Promise((resolve, reject) => {
        ffmpeg.ffprobe(videoPath, (err, metadata) => {
            if (err) reject(err);
            resolve(metadata.format.duration);
        });
    });
};

// Track processed file in Supabase
const trackProcessedFile = async (command, outputUrl) => {
    try {
        const { data, error } = await supabase
            .from('media_assets')
            .insert({
                project_id: command.metadata.projectId,
                file_path: outputUrl,
                type: 'processed',
                original_name: command.metadata.originalFileName,
                processing_type: command.metadata.processingType,
                created_by: command.metadata.userId,
                command_used: command.ffmpegCommand
            })
            .select()
            .single();

        if (error) throw error;
        return data;
    } catch (error) {
        console.error('Error tracking processed file:', error);
        throw error;
    }
};

// Enhanced video identification with content analysis
const identifyRelevantContent = (mediaAnalyses, query) => {
    const queryTerms = query.toLowerCase().split(' ');
    
    // Score each video based on content relevance
    const scoredVideos = mediaAnalyses
        .filter(media => media.type === 'video')
        .map(video => {
            let score = 0;
            let relevantMoments = [];
            
            // Safely handle frame analysis
            if (video.analysis && video.analysis.frameAnalysis) {
                video.analysis.frameAnalysis.forEach(frame => {
                    const analysis = frame.analysis.toLowerCase();
                    queryTerms.forEach(term => {
                        if (analysis.includes(term)) {
                            score += 1;
                            if (frame.isSignificant) {
                                score += 2;
                                relevantMoments.push({
                                    timestamp: frame.timestamp,
                                    analysis: frame.analysis
                                });
                            }
                        }
                    });
                });
            }
            
            // Safely handle significant moments
            if (video.analysis && video.analysis.significantMoments) {
                video.analysis.significantMoments.forEach(moment => {
                    const reason = moment.reason.toLowerCase();
                    queryTerms.forEach(term => {
                        if (reason.includes(term)) {
                            score += 3;
                            relevantMoments.push(moment);
                        }
                    });
                });
            }

            // If no analysis is available, give a base score
            if (!video.analysis || (!video.analysis.frameAnalysis && !video.analysis.significantMoments)) {
                score = 1; // Give a minimal score to videos without analysis
                relevantMoments = [{
                    timestamp: "0",
                    reason: "Video content to be analyzed"
                }];
            }
                
        return {
                video,
                score,
                relevantMoments: [...new Set(relevantMoments)] // Remove duplicates
            };
        })
        .filter(result => result.score > 0)
        .sort((a, b) => b.score - a.score);

    return scoredVideos;
};

// Update chatModel initialization with structured output
const chatModel = new ChatOpenAI({
    modelName: "gpt-4o-mini",
    temperature: 0,
    callbacks: [new ConsoleCallbackHandler()]
}).withStructuredOutput(RecipeSuggestionSchema);

const embeddings = new OpenAIEmbeddings({
    modelName: "text-embedding-3-small"
});

// Initialize Pinecone with proper configuration
console.log('Loading Pinecone configuration...');
console.log('PINECONE_API_KEY present:', !!process.env.PINECONE_API_KEY);
console.log('PINECONE_INDEX_NAME:', process.env.PINECONE_INDEX_NAME);

// Initialize Pinecone client
const pinecone = new Pinecone();
const index = pinecone.index(process.env.PINECONE_INDEX_NAME);

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

// Frame analysis function
const analyzeVideoFrames = async (videoPath, recipeContext) => {
    const frameAnalysis = [];
    const significantFrames = [];
    const analysisId = uuidv4();
    console.log(`\n=== Starting Video Frame Analysis [${analysisId}] ===`);
    console.log('Video path:', videoPath);
    console.log('Setting up FFmpeg with scene detection...');

    // Ensure complete directory structure exists
    const baseDir = '/tmp/ffmpeg';
    const framesDir = path.join(baseDir, 'frames');
    try {
        // Create base ffmpeg directory if it doesn't exist
        if (!fs.existsSync(baseDir)) {
            await fs.promises.mkdir(baseDir, { recursive: true });
            console.log(`Created base directory: ${baseDir}`);
        }
        
        // Create frames directory if it doesn't exist
        if (!fs.existsSync(framesDir)) {
            await fs.promises.mkdir(framesDir, { recursive: true });
            console.log(`Created frames directory: ${framesDir}`);
        }

        // Clean up any existing frames before starting
        const existingFiles = fs.readdirSync(framesDir);
        for (const file of existingFiles) {
            if (file.endsWith('.jpg')) {
                try {
                    await fs.promises.unlink(path.join(framesDir, file));
                } catch (err) {
                    console.error(`Error deleting existing frame ${file}:`, err);
                }
            }
        }
    } catch (error) {
        console.error('Error creating directories:', error);
        throw new Error(`Failed to create required directories: ${error.message}`);
    }

    return new Promise((resolve, reject) => {
        let totalFrames = 0;
        let processedFrames = 0;
        let ffmpegOutput = '';

        const ffmpegProcess = ffmpeg(videoPath)
            .outputOptions([
                // Extract 1 frame every 5 seconds
                '-vf', 'fps=1/5',  // Changed from 1 fps to 1 frame every 5 seconds
                '-frame_pts', '1',
                '-t', '300'  // 5-minute timeout in seconds
            ])
            .output('/tmp/ffmpeg/frames/frame_%d.jpg')
            .on('start', (commandLine) => {
                console.log(`\n=== FFmpeg Processing Started [${analysisId}] ===`);
                console.log('FFmpeg command:', commandLine);
                console.log('Video input path:', videoPath);
                console.log('Output frames path:', '/tmp/ffmpeg/frames/frame_%d.jpg');
                console.log('FFmpeg options:', {
                    frameExtraction: 'fps=1/5',
                    timeout: '300 seconds'
                });
                
                // Verify input file format
                ffmpeg.ffprobe(videoPath, (err, metadata) => {
                    if (err) {
                        console.error('Error probing input file:', err);
                        return;
                    }
                    console.log('Input file metadata:', {
                        format: metadata.format.format_name,
                        duration: metadata.format.duration,
                        bitrate: metadata.format.bit_rate,
                        size: metadata.format.size,
                        streams: metadata.streams.map(s => ({
                            codec_type: s.codec_type,
                            codec_name: s.codec_name,
                            width: s.width,
                            height: s.height,
                            r_frame_rate: s.r_frame_rate
                        }))
                    });
                });
            })
            .on('progress', (progress) => {
                console.log(`\n=== FFmpeg Progress Update [${analysisId}] ===`);
                console.log(`Progress: ${progress.percent}% complete`);
                console.log(`Frame: ${progress.frames}`);
                console.log(`FPS: ${progress.currentFps}`);
                console.log(`Bitrate: ${progress.currentKbps} kbps`);
                console.log(`Time: ${progress.timemark}`);
                totalFrames = progress.frames;
            })
            .on('stderr', (stderrLine) => {
                ffmpegOutput += stderrLine + '\n';
                console.log(`[${analysisId}] FFmpeg:`, stderrLine);
            })
            .on('end', async () => {
                console.log(`\n=== Video Analysis Summary [${analysisId}] ===`);
                
                // Check output files immediately after FFmpeg completion
                    const files = fs.readdirSync(framesDir)
                        .filter(f => f.endsWith('.jpg'))
                        .sort((a, b) => {
                            const numA = parseInt(a.match(/\d+/)[0]);
                            const numB = parseInt(b.match(/\d+/)[0]);
                            return numA - numB;
                        });

                    console.log('Output directory contents:', {
                        totalFiles: files.length,
                        fileNames: files.slice(0, 5),
                    hasMoreFiles: files.length > 5 ? `and ${files.length - 5} more...` : 'no more files'
                    });
                    
                    if (files.length === 0) {
                        console.error('No frames were generated by FFmpeg');
                        reject(new Error('FFmpeg did not generate any frames'));
                        return;
                    }

                    // Create a Map to store frame data before processing
                    const frameDataMap = new Map();
                    
                    // First, read all frame data into memory
                    console.log('Reading all frames into memory...');
                    for (const file of files) {
                        try {
                            const framePath = path.join(framesDir, file);
                            if (fs.existsSync(framePath)) {
                                const frameData = await fs.promises.readFile(framePath);
                                frameDataMap.set(file, frameData);
                            }
                        } catch (error) {
                            console.error(`Error reading frame ${file}:`, error);
                        }
                    }

                    console.log(`Successfully loaded ${frameDataMap.size}/${files.length} frames into memory`);

                // Process frames in batches
                const batchSize = 4;
                const batches = Array.from(frameDataMap.entries())
                    .reduce((acc, curr, i) => {
                        const batchIndex = Math.floor(i / batchSize);
                        if (!acc[batchIndex]) acc[batchIndex] = [];
                        acc[batchIndex].push(curr);
                        return acc;
                    }, []);

                console.log(`Processing ${batches.length} batches of frames...`);

                // Process each batch with LangChain
                for (const [batchIndex, batch] of batches.entries()) {
                    try {
                        console.log(`\n=== Processing Batch ${batchIndex + 1}/${batches.length} [${analysisId}] ===`);
                        
                    const messages = [
                            new SystemMessage({
                                content: `You are analyzing a video frame. Analyze: 
                        1. Visual composition and key actions
                        2. Significant cooking moments and techniques
                        3. Ingredients and measurements visible
                        4. Educational value and technical details
                        
                        Provide clear, direct observations without using markdown formatting or special characters.
                                Context: ${recipeContext}`
                            }),
                        new HumanMessage({
                            content: [
                                { 
                                        type: "text", 
                                        text: "Analyze these frames and describe any significant moments, actions, or visual elements in plain text." 
                                    },
                                    ...batch.map(([file, frameData]) => ({
                                    type: "image_url", 
                                    image_url: {
                                            url: `data:image/jpeg;base64,${frameData.toString('base64')}`,
                                        detail: "auto"
                                    }
                                    }))
                            ]
                        })
                    ];

                        // Use RunnableSequence for structured output
                        const chain = RunnableSequence.from([
                            chatModel,
                            (output) => {
                                try {
                                    if (!output || typeof output !== 'object') {
                                        console.error('Invalid output from chatModel:', output);
                                        return false;
                                    }

                                    // Process each frame's analysis
                                    batch.forEach(([file, _], index) => {
                                        const timestamp = parseInt(file.match(/\d+/)[0]);
                                        const analysis = output.content || output.response || '';

                                        if (typeof analysis !== 'string') {
                                            console.error('Invalid analysis type:', typeof analysis);
                                            return;
                                        }

                                        const analysisText = analysis.toLowerCase();
                                        const isSignificant = analysisText.includes('significant') || 
                                                            analysisText.includes('important') || 
                                                            analysisText.includes('key moment');

                    frameAnalysis.push({
                                            timestamp: timestamp.toString(),
                                            analysis: analysis,
                                            isSignificant: isSignificant
                                        });

                                        if (isSignificant) {
                        significantFrames.push({ 
                                                timestamp: timestamp.toString(),
                                                reason: analysis
                                            });
                                        }
                                    });
                                    return true;
                } catch (error) {
                                    console.error(`Error processing batch ${batchIndex + 1}:`, error);
                                    console.error('Error context:', {
                                        output: output,
                                        batchSize: batch.length,
                                        currentFrameAnalysisCount: frameAnalysis.length
                                    });
                                    return false;
                                }
                            }
                        ]);

                        await chain.invoke(messages);
                        
                        // Clean up processed frames with better error handling
                        for (const [file, _] of batch) {
                                const framePath = path.join(framesDir, file);
                            try {
                                if (fs.existsSync(framePath)) {
                                    await fs.promises.unlink(framePath);
                                    console.log(`Deleted frame ${file} after processing`);
                                }
                            } catch (err) {
                                console.error(`Error deleting frame ${file}:`, err);
                                // Continue processing even if deletion fails
                            }
                        }
                    } catch (error) {
                        console.error(`Error processing batch ${batchIndex + 1}:`, error);
                    }
                }

                console.log(`\n=== Frame Processing Summary [${analysisId}] ===`);
                    console.log(`Total frames processed: ${frameAnalysis.length}`);
                    console.log(`Significant moments found: ${significantFrames.length}`);

                    resolve({ frameAnalysis, significantFrames });
            })
            .on('error', (err) => {
                console.error(`\n=== FFmpeg Error [${analysisId}] ===`);
                console.error('Error details:', err);
                console.error('FFmpeg context:', {
                    inputPath: videoPath,
                    outputDir: framesDir,
                    ffmpegOutput
                });
                reject(err);
            });

        // Handle timeout
        const timeout = setTimeout(() => {
            ffmpegProcess.kill('SIGKILL');
            reject(new Error('FFmpeg processing timed out after 5 minutes'));
        }, 300000); // 5 minutes timeout

        // Ensure timeout is cleared on success or error
        ffmpegProcess.on('end', () => clearTimeout(timeout));
        ffmpegProcess.on('error', () => clearTimeout(timeout));

        ffmpegProcess.run();
    });
};

// Analyze audio file using FFmpeg, Whisper, and OpenAI
async function analyzeAudio(audioPath) {
    const analysisId = uuidv4();
    console.log(`\n=== Starting Audio Analysis [${analysisId}] ===`);
    console.log('Audio path:', audioPath);

    return new Promise((resolve, reject) => {
        const ffmpegProcess = ffmpeg(audioPath)
            .toFormat('wav')
            .audioFrequency(16000)
            .audioChannels(1)
            .on('start', (commandLine) => {
                console.log(`[${analysisId}] FFmpeg command:`, commandLine);
            })
            .on('progress', (progress) => {
                console.log(`[${analysisId}] Processing: ${progress.percent}% done`);
            })
            .on('error', (err) => {
                console.error(`[${analysisId}] Error processing audio:`, err);
                reject(err);
            })
            .on('end', async () => {
                try {
                    // Get audio metadata first
                    console.log(`[${analysisId}] Getting audio metadata...`);
                    const audioMetadata = await new Promise((resolve, reject) => {
                        ffmpeg.ffprobe(audioPath, (err, metadata) => {
                            if (err) reject(err);
                            resolve({
                                duration: metadata.format.duration,
                                size: metadata.format.size,
                                bitrate: metadata.format.bit_rate,
                                format: metadata.format.format_name
                            });
                        });
                    });
                    console.log(`[${analysisId}] Audio metadata:`, audioMetadata);

                    // Transcribe with Whisper first
                    console.log(`[${analysisId}] Transcribing audio with Whisper...`);
                    const formData = new FormData();
                    formData.append('file', fs.createReadStream('/tmp/ffmpeg/audio/temp.wav'));
                    formData.append('model', 'whisper-1');
                    formData.append('language', 'en');
                    formData.append('response_format', 'verbose_json');

                    const transcriptionResponse = await fetch('https://api.openai.com/v1/audio/transcriptions', {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
                            ...formData.getHeaders()
                        },
                        body: formData
                    });

                    if (!transcriptionResponse.ok) {
                        throw new Error(`Whisper API error: ${transcriptionResponse.status} ${transcriptionResponse.statusText}`);
                    }

                    const transcriptionData = await transcriptionResponse.json();
                    console.log(`[${analysisId}] Transcription completed successfully`);

                    // Structure the transcription data with metadata
                    const audioData = {
                        metadata: audioMetadata,
                        transcription: {
                            text: transcriptionData.text,
                            segments: transcriptionData.segments.map(segment => ({
                                start: segment.start,
                                end: segment.end,
                                text: segment.text,
                                confidence: segment.confidence
                            })),
                            words: transcriptionData.words.map(word => ({
                                word: word.word,
                                start: word.start,
                                end: word.end,
                                confidence: word.confidence
                            }))
                        }
                    };

                    // Now analyze with LangChain
                    console.log(`[${analysisId}] Analyzing transcription with LangChain...`);
                    
                    // Use RunnableSequence for structured output
                    const chain = RunnableSequence.from([
                        {
                            messages: (input) => [
                        new SystemMessage({
                            content: `You are analyzing transcribed audio content from a cooking video. Focus on:
                            1. Identifying cooking instructions and techniques
                            2. Ingredient mentions and measurements
                            3. Important timing information
                            4. Key steps in the recipe
                            5. Chef's tips or special notes
                            
                                    The audio is ${input.metadata.duration} seconds long.`
                        }),
                        new HumanMessage({
                            content: `Analyze this transcribed cooking content:
                            
                                    Full Transcription: ${input.transcription.text}
                            
                                    Detailed Segments: ${JSON.stringify(input.transcription.segments.map(s => ({
                                time: `${s.start}-${s.end}`,
                                text: s.text
                            })))}`
                        })
                            ]
                        },
                        chatModel,
                        (output) => {
                            try {
                                return {
                        metadata: audioData.metadata,
                        transcription: audioData.transcription,
                        analysis: {
                                        content: output.content,
                                        segments: audioData.transcription.segments.map(segment => ({
                                            start: segment.start,
                                            end: segment.end,
                                            text: segment.text,
                                            type: determineSegmentType(segment.text)
                                        }))
                                    }
                                };
                } catch (error) {
                                console.error(`[${analysisId}] Error processing analysis output:`, error);
                                throw error;
                            }
                        }
                    ]);

                    const result = await chain.invoke(audioData);
                    console.log(`[${analysisId}] Analysis completed successfully`);
                    resolve(result);
                } catch (error) {
                    console.error(`[${analysisId}] Error in audio processing:`, error);
                    reject(error);
                }
            });

        // Handle timeout
        const timeout = setTimeout(() => {
            ffmpegProcess.kill('SIGKILL');
            reject(new Error('FFmpeg processing timed out after 5 minutes'));
        }, 300000); // 5 minutes timeout

        // Ensure timeout is cleared on success or error
        ffmpegProcess.on('end', () => clearTimeout(timeout));
        ffmpegProcess.on('error', () => clearTimeout(timeout));

        ffmpegProcess.save('/tmp/ffmpeg/audio/temp.wav');
    });
}

// Helper function to determine segment type
function determineSegmentType(text) {
    const lowerText = text.toLowerCase();
    if (lowerText.includes('ingredient') || lowerText.includes('measurement')) return 'ingredient';
    if (lowerText.includes('step') || lowerText.includes('instruction')) return 'instruction';
    if (lowerText.includes('tip') || lowerText.includes('note')) return 'tip';
    if (lowerText.includes('time') || lowerText.includes('minute') || lowerText.includes('second')) return 'timing';
    return 'general';
}

// Helper function to convert FFmpeg time format to seconds
function timeToSeconds(timeStr) {
    if (!timeStr) return 0;
    
    // If timeStr is already a number, return it
    if (typeof timeStr === 'number') return timeStr;
    
    // If it's a simple number as string (e.g., "5"), parse it
    if (!isNaN(timeStr)) return parseFloat(timeStr);
    
    console.log('🕒 Parsing timestamp:', timeStr);
    
    try {
        // Handle HH:MM:SS format
        if (timeStr.includes(':')) {
            const parts = timeStr.split(':').map(Number);
            if (parts.length === 3) {
                const [hours, minutes, seconds] = parts;
                return (hours * 3600) + (minutes * 60) + seconds;
            } else if (parts.length === 2) {
                const [minutes, seconds] = parts;
                return (minutes * 60) + seconds;
            }
        }
        
        // Default to parsing as seconds
        const seconds = parseFloat(timeStr);
        return isNaN(seconds) ? 0 : seconds;
    } catch (error) {
        console.error('❌ Error parsing timestamp:', timeStr, error);
        return 0;
    }
}

// Enhanced video command generation with better analysis integration
const generateVideoCommand = async (analysisResult, query, projectId, userId) => {
    console.log('\n=== Generating Video Command with Analysis ===');
    console.log('Query:', query);
    
    // Identify relevant content
    const relevantContent = identifyRelevantContent(analysisResult.mediaAnalyses, query);
    
    if (relevantContent.length === 0) {
        return {
            message: "I couldn't find any videos with grilling or cooking content. Could you provide more details about what you're looking for?",
            command: null
        };
    }

    const bestMatch = relevantContent[0];
    console.log('Best matching video:', {
        id: bestMatch.video.id,
        name: bestMatch.video.name,
        score: bestMatch.score,
        relevantMoments: bestMatch.relevantMoments
    });

    // Sort moments by timestamp for sequential editing
    const sortedMoments = bestMatch.relevantMoments
        .sort((a, b) => timeToSeconds(a.timestamp) - timeToSeconds(b.timestamp));

    // Add validation logging
    console.log('\n🕒 Duration Validation:');
    console.log('First Timestamp:', sortedMoments[0]?.timestamp, '→', timeToSeconds(sortedMoments[0]?.timestamp));
    console.log('Last Timestamp:', sortedMoments[sortedMoments.length - 1]?.timestamp, '→', timeToSeconds(sortedMoments[sortedMoments.length - 1]?.timestamp));
    
    const startTimeSeconds = timeToSeconds(sortedMoments[0]?.timestamp);
    const endTimeSeconds = timeToSeconds(sortedMoments[sortedMoments.length - 1]?.timestamp);
    const duration = endTimeSeconds - startTimeSeconds;
    
    console.log('⏱️ Duration Calculation:');
    console.log('Start Time (s):', startTimeSeconds);
    console.log('End Time (s):', endTimeSeconds);
    console.log('Duration (s):', duration);
    
    if (isNaN(duration)) {
        console.error('❌ Invalid Duration Detected!');
        console.error('Timestamps:', {
            first: sortedMoments[0],
            last: sortedMoments[sortedMoments.length - 1],
            allTimestamps: sortedMoments.map(m => m.timestamp)
        });
    }

    // Ensure we have valid duration
    const validatedDuration = !isNaN(duration) && duration > 0 ? duration : 30; // Default to 30 seconds if invalid

    // Generate a user-friendly response message first
    const message = `I've found some great cooking moments in your video${bestMatch.video.name ? ` "${bestMatch.video.name}"` : ''}:

${sortedMoments.map((moment, idx) => 
    `${idx + 1}. ${moment.reason || moment.analysis}`
).join('\n')}

Would you like me to create a focused version highlighting these techniques? This will help viewers focus on the key steps.`;

    // Technical command details are only included in the command object
    const command = {
        operation: 'trim',
        description: `Trim video ${bestMatch.video.id} to focus on key moments:\n${
            sortedMoments.map(m => `- ${m.timestamp}: ${m.reason || m.analysis}`).join('\n')
        }`,
        ffmpegCommand: `-ss ${startTimeSeconds} -t ${validatedDuration}`,
        inputFiles: [bestMatch.video.url],
        outputFile: `/tmp/ffmpeg/output/${Date.now()}_trimmed_${bestMatch.video.name}`,
        expectedDuration: validatedDuration,
        startTime: startTimeSeconds,
        endTime: endTimeSeconds,
        metadata: {
            projectId,
            userId,
            originalFileName: bestMatch.video.name,
            assetId: bestMatch.video.id,
            processingType: 'trim'
        }
    };

    console.log('🎬 Generated Command:', {
        operation: command.operation,
        ffmpegCommand: command.ffmpegCommand,
        expectedDuration: command.expectedDuration,
        startTime: command.startTime,
        endTime: command.endTime
    });

    return {
        message,
        command,
        suggestedEnhancements: [
            {
                technique: "Focus on Key Steps",
                reason: "This will help viewers learn the techniques more effectively"
            },
            {
                technique: "Maintain Flow",
                reason: "The edit will preserve the natural progression of the cooking process"
            }
        ]
    };
};

// Enhanced combined analysis with better context handling
const generateCombinedAnalysis = async (query, videoPath, recipeData) => {
    const analysisId = uuidv4();
    console.log(`\n=== Combined Analysis [${analysisId}] START ===`);
    console.log('Query:', query);
    console.log('Project Data:', JSON.stringify(recipeData, null, 2));
    
    try {
        // Get media assets from storage bucket instead of database
        console.log(`[${analysisId}] Fetching media assets from Supabase storage...`);
        const { data: mediaFiles, error: storageError } = await supabase
            .storage
            .from('cookcut-media')
            .list(`media/${recipeData.projectId}/raw`);

        if (storageError) {
            console.error(`[${analysisId}] Supabase storage error:`, storageError);
            throw storageError;
        }

        // Early check for no media files
        if (!mediaFiles || mediaFiles.length === 0) {
            console.log(`[${analysisId}] No media files found in project`);
        return {
                response: "I don't see any videos or audio files in your project yet. Would you like help uploading some content?",
            videoCommands: [],
            mediaAnalyses: [],
                recipeAnalysis: { suggestedEnhancements: [] },
                futureSuggestions: { contentIdeas: [] }
            };
        }

        console.log(`[${analysisId}] Found ${mediaFiles.length} media files`);

        // Classify the query intent before proceeding with analysis
        const queryIntent = classifyQueryIntent(query);
        console.log(`[${analysisId}] Query intent classified as:`, queryIntent);

        // If not a video modification command, skip media analysis
        if (queryIntent.type !== 'video_modification') {
            console.log(`[${analysisId}] Query does not require video analysis, proceeding with conversation`);
            
            // Generate conversational response using LangChain
            const messages = [
                new SystemMessage({
                    content: `You are a friendly cooking assistant helping users with their recipe videos. 
                    Your responses should be conversational and user-friendly.
                    
                    Current context:
                    - Project has ${mediaFiles.length} media files
                    - User query type: ${queryIntent.type}
                    - User query category: ${queryIntent.category}`
                }),
                new HumanMessage({
                    content: `Query: ${query}
                    Project Context: ${JSON.stringify(recipeData)}`
                })
            ];

            const response = await chatModel.invoke(messages);
            console.log(`[${analysisId}] Generated conversational response`);

            return {
                response: response.response,
                videoCommands: [],
                mediaAnalyses: [],
                recipeAnalysis: { suggestedEnhancements: [] },
                futureSuggestions: { contentIdeas: [] }
            };
        }

        // Proceed with full media analysis only for video modification queries
        console.log(`[${analysisId}] Analyzing media assets for video modification...`);
        const mediaAnalyses = await Promise.all(
            mediaFiles.map(async (file) => {
                console.log(`[${analysisId}] Analyzing file:`, file.name);
                try {
                    const { data: { signedUrl } } = await supabase
                        .storage
                        .from('cookcut-media')
                        .createSignedUrl(`media/${recipeData.projectId}/raw/${file.name}`, 3600);
                    
                    if (file.name.match(/\.(mp4|mov|avi)$/i)) {
                        console.log(`[${analysisId}] Analyzing video:`, file.name);
                        const analysis = await analyzeVideoFrames(signedUrl, recipeData);
                        return {
                            id: file.id || uuidv4(),
                            name: file.name,
                            type: 'video',
                            url: signedUrl,
                            analysis
                        };
                    } else if (file.name.match(/\.(mp3|wav|m4a)$/i)) {
                        console.log(`[${analysisId}] Analyzing audio:`, file.name);
                        const analysis = await analyzeAudio(signedUrl);
                        return {
                            id: file.id || uuidv4(),
                            name: file.name,
                            type: 'audio',
                            url: signedUrl,
                            analysis
                        };
                    }
                    return null;
                } catch (error) {
                    console.error(`[${analysisId}] Error analyzing file ${file.name}:`, error);
                    return null;
                }
            })
        );

        // Filter out null values and prepare response
        const validMediaAnalyses = mediaAnalyses.filter(Boolean);
        console.log(`[${analysisId}] Media analysis complete. Found ${validMediaAnalyses.length} valid analyses`);

        // Generate command if needed
        const commandResult = await generateVideoCommand(
            { mediaAnalyses: validMediaAnalyses },
            query,
            recipeData.projectId,
            recipeData.userId
        );

        // Structure the final response
        const structuredResponse = {
            response: commandResult.message || "I've analyzed your content. What would you like to do with it?",
            videoCommands: commandResult.command ? [commandResult.command] : [],
            mediaAnalyses: validMediaAnalyses,
            recipeAnalysis: {
                suggestedEnhancements: commandResult.suggestedEnhancements || []
            },
            futureSuggestions: {
                contentIdeas: []
            }
        };

        console.log(`\n=== Combined Analysis [${analysisId}] END ===`);
        return structuredResponse;

    } catch (error) {
        console.error(`[${analysisId}] Error in generateCombinedAnalysis:`, error);
        console.error(`[${analysisId}] Error stack:`, error.stack);
        console.log(`\n=== Combined Analysis [${analysisId}] ERROR END ===`);
        throw error;
    }
};

// Helper function to classify query intent
function classifyQueryIntent(query) {
    const lowerQuery = query.toLowerCase();
    
    // Video modification commands
    if (lowerQuery.includes('trim') || 
        lowerQuery.includes('cut') || 
        lowerQuery.includes('clip') ||
        lowerQuery.includes('merge') ||
        lowerQuery.includes('edit') ||
        lowerQuery.includes('modify')) {
        return {
            type: 'video_modification',
            category: 'edit'
        };
    }
    
    // Recipe questions
    if (lowerQuery.includes('recipe') ||
        lowerQuery.includes('ingredient') ||
        lowerQuery.includes('cook') ||
        lowerQuery.includes('bake')) {
        return {
            type: 'recipe_question',
            category: 'information'
        };
    }
    
    // General conversation
    return {
        type: 'conversation',
        category: 'general'
    };
}

// Cleanup helper
const cleanupTempFiles = async (command) => {
    console.log('Cleaning up temp files...');
    try {
        // Clean input files from temp
        for (const inputFile of command.inputFiles) {
            if (inputFile.startsWith(FFMPEG_DIRS.temp)) {
                await fs.promises.unlink(inputFile);
                console.log(`Cleaned up input file: ${inputFile}`);
            }
        }
        
        // Clean output file from temp if it exists
        if (command.outputFile.startsWith(FFMPEG_DIRS.temp)) {
            await fs.promises.unlink(command.outputFile);
            console.log(`Cleaned up output file: ${command.outputFile}`);
        }
        
        // Clean any frames or audio files
        await Promise.all([
            fs.promises.readdir(FFMPEG_DIRS.frames),
            fs.promises.readdir(FFMPEG_DIRS.audio)
        ]).then(([frameFiles, audioFiles]) => {
            return Promise.all([
                ...frameFiles.map(file => fs.promises.unlink(path.join(FFMPEG_DIRS.frames, file))),
                ...audioFiles.map(file => fs.promises.unlink(path.join(FFMPEG_DIRS.audio, file)))
            ]);
        });
        
        console.log('Cleanup completed successfully');
    } catch (error) {
        console.error('Error during cleanup:', error);
        // Don't throw - cleanup errors shouldn't stop the process
    }
};

// Execute FFmpeg command
const executeFFmpegCommand = async (command) => {
    console.log('Executing FFmpeg command:', command);
    
    try {
        // Validate command first
        await validateFFmpegCommand(command);
        
        // Execute the command with structured output
        const result = await new Promise((resolve, reject) => {
            let progress = 0;
            let duration = 0;
            let ffmpegOutput = '';

            const ffmpegProcess = ffmpeg()
                .input(command.inputFiles[0])
                .outputOptions(command.ffmpegCommand.split(' '))
                .output(command.outputFile)
                .on('start', (commandLine) => {
                    console.log('FFmpeg process started with command:', commandLine);
                    
                    // Get video duration for progress calculation
                    ffmpeg.ffprobe(command.inputFiles[0], (err, metadata) => {
                        if (!err && metadata.format) {
                            duration = metadata.format.duration;
                        }
                    });
                })
                .on('progress', (progressData) => {
                    if (duration > 0) {
                        progress = (progressData.percent || 0).toFixed(2);
                        console.log(`Processing: ${progress}% done`);
                    }
                    ffmpegOutput += `Progress: ${progress}%\n`;
                })
                .on('stderr', (stderrLine) => {
                    ffmpegOutput += stderrLine + '\n';
                    console.log('FFmpeg:', stderrLine);
                })
                .on('error', (err, stdout, stderr) => {
                    console.error('FFmpeg error:', err.message);
                    console.error('FFmpeg stderr:', stderr);
                    reject(new Error(`FFmpeg processing failed: ${err.message}\n\nOutput: ${ffmpegOutput}`));
                })
                .on('end', () => {
                    console.log('FFmpeg processing completed');
                    resolve({
                        success: true,
                        output: command.outputFile,
                        duration,
                        progress: 100,
                        logs: ffmpegOutput
                    });
                });

            // Handle timeout
            const timeout = setTimeout(() => {
                ffmpegProcess.kill('SIGKILL');
                reject(new Error('FFmpeg processing timed out after 5 minutes'));
            }, 300000); // 5 minutes timeout

            // Ensure timeout is cleared on success
            ffmpegProcess.on('end', () => clearTimeout(timeout));
            ffmpegProcess.on('error', () => clearTimeout(timeout));

            ffmpegProcess.run();
        });
        
        // Upload to Supabase
        const fileName = path.basename(command.outputFile);
        const storagePath = `media/${command.metadata.projectId}/processed/${fileName}`;
        
        const { data: uploadData, error: uploadError } = await supabase.storage
            .from('cookcut-media')
            .upload(storagePath, fs.createReadStream(command.outputFile));
            
        if (uploadError) throw uploadError;
        
        // Get public URL
        const { data: { publicUrl } } = supabase.storage
            .from('cookcut-media')
            .getPublicUrl(storagePath);
            
        // Track in database
        await trackProcessedFile(command, publicUrl);
        
        // Cleanup temp files
        await cleanupTempFiles(command);
        
        return publicUrl;
    } catch (error) {
        console.error('Error executing FFmpeg command:', error);
        throw error;
    }
};

// Enable background callbacks for LangSmith tracing
process.env.LANGCHAIN_CALLBACKS_BACKGROUND = 'true';

// Download video utility
const downloadVideo = async (url, destination) => {
    console.log('Downloading video from:', url);
    console.log('Saving to:', destination);
    
    try {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Failed to fetch video: ${response.status} ${response.statusText}`);
        }
        
        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);
        fs.writeFileSync(destination, buffer);
        
        console.log('Video download completed successfully');
    } catch (error) {
        console.error('Error downloading video:', error);
        throw error;
    }
};

module.exports = {
    generateCombinedAnalysis,
    downloadVideo,
    generateVideoCommand,
    validateFFmpegCommand,
    trackProcessedFile,
    executeFFmpegCommand,
    analyzeVideoFrames,
    analyzeAudio
};