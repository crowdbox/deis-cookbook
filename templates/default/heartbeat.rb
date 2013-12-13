=begin
In order to get a list of the running apps we use `docker ps` to get the active containers. Then
use `docker inspect` to drill down into the 'Volumes' attribute to get the app name running in the
container. We then send the list of app names every minute.

Security is done by piggybacking off Chef's RSA 'validation.pem' file which is always the same for
all nodes in a chef configuration.
=end

require 'json'
require 'socket'

CHEF_VALIDATION_PEM = File.read('/etc/chef/validation.pem').strip

loop do
  # Get the running docker containers
  # First line of output is column titles so strip it
  containers = `docker ps`.lines.to_a[1..-1]
  ids = containers.map do |container|
    # First column is the id
    container.split(' ').first
  end

  apps = []
  # Run the detailed `docker inspect` on each container
  ids.each do |id|
    # Output is wrapped in '[]'
    data = JSON.parse(`docker inspect #{id}`).first
    # Following returns something like 'opdemand-example--ruby--sinatra-4'
    app_with_version = data['Volumes']['/app'].split('/')[5]
    # Strip off the version number at the end
    apps << app_with_version[/(.*)-v[0-9]+$/, 1]
  end

  # This is the heartbeat payload
  payload = []
  payload << 'HEARTBEAT' # First line is the task
  payload << CHEF_VALIDATION_PEM # Security measure
  payload += apps # List of apps
  payload << "\r\n" # Syntax for ending communication
  # New client needed for each loop as the Rendevous server closes each connection after
  # successfully receiving a payload.
  client = TCPSocket.new(ENV['CONTROLLER_IP'], 6315)
  client.write(payload.join("\n"))

  sleep 60
end
