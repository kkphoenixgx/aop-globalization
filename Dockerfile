FROM eclipse-temurin:21-jre

# Install Node.js
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy the compiled shadow JAR and package assets
COPY build/libs/jason-ipc-all.jar /app/build/libs/jason-ipc-all.jar
COPY package.json /app/package.json
COPY bin /app/bin
COPY test /app/test

# Install the npm package globally
RUN npm install -g .

# Run the test project agent by default
CMD ["panteao", "test/project.jcm"]
