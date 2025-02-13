# Use Node.js base image
FROM node:18

# Create app directory
WORKDIR /usr/src/app

# Install ffmpeg
RUN apt-get update && \
    apt-get install -y ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy all other source code files
COPY . .

# Use nodemon in development for auto-reloading
RUN npm install -g nodemon

# Create FFmpeg working directories
RUN mkdir -p /tmp/ffmpeg/uploads /tmp/ffmpeg/output

# Expose the port the app runs on
EXPOSE 3000

# Add startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Command to run the application
CMD ["nodemon", "--watch", "src", "src/server.js"]

# Start the application
ENTRYPOINT ["docker-entrypoint.sh"] 