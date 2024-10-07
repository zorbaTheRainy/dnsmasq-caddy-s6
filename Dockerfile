# Use the official Golang image to build the application
FROM golang:1.20 AS builder

# Set the working directory inside the container
WORKDIR /app

# Download the source code
RUN git clone https://github.com/jpillora/webproc.git .

# Compile the source code
RUN go build -o webproc


# Expose the port that the application will run on
EXPOSE 8080

