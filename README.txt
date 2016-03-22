
This is the base image that is then used for development, but also for production.
docker-compose is used to mount the files inside the container when in production, but there is another container that actually copies them in for proper production.

This image now has problems with US export as it includes the JCE unlimited strength policy, however we download this automatically as part of the build so although the images may have problems the source repo shouldn't.

To rebuild this image use:

docker build -t oxit/sakai:11.x .

These images are available on the docker hub and built automatically when new commits are pushed to this repository.

There are 2 environmental variables that can be set:

- CATALINA_LISTEN - The IP address to listen on (default to 0.0.0.0).
- CATALINA_JMX_PORT - The port that the JMX connector should listen on (default to 5400).
