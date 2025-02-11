# FFmpeg Server

A simple Docker-based FFmpeg server for video processing.

## Setup

1. Install Docker and Docker Compose on your EC2 instance:
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
```

2. Start Docker service:
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

3. Build and run the container:
```bash
docker-compose up -d
```

## API Endpoints

### Health Check
```bash
GET /health
```

### Process Video
```bash
POST /process
Content-Type: application/json

{
    "command": "ffmpeg [your-ffmpeg-command]"
}
```

### Check Status
```bash
GET /status/:jobId
```

## Example Usage

```bash
# Trim video
curl -X POST http://your-server/process \
  -H "Content-Type: application/json" \
  -d '{"command": "ffmpeg -i input.mp4 -ss 00:00:00 -t 00:00:10 -c copy output.mp4"}'

# Check status
curl http://your-server/status/[jobId]
``` 