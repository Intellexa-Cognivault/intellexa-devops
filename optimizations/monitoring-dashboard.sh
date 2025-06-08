# Install lightweight monitoring
docker run -d --name glances \
  --pid host \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  nicolargo/glances:alpine

# Access at http://localhost:61208