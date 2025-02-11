# Use Node.js base image
FROM node:18-slim

# Install FFmpeg and required dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/

# Create FFmpeg working directories
RUN mkdir -p /tmp/ffmpeg/uploads /tmp/ffmpeg/output

# Expose the port the app runs on
EXPOSE 3000

# Add startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Start the application
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "src/server.js"] 