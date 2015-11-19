# This is the dockerfile for the Sakai tomcat.
# Basically this is just a copy of tomcat that has it's classloaders modified for Sakai.
# This doesn't have a copy of Sakai put into it so it can be used for development where Sakai is mounted from outside
# the container.

# Use the Sun JVM 7
FROM oxit/java:jdk-7u76

MAINTAINER Matthew Buckett <matthew.buckett@it.ox.ac.uk>

WORKDIR /tmp

# Create the group and user for Sakai
RUN groupadd --gid 10000 sakai && \
  useradd --uid 10000 --gid 10000 --system sakai 

# Need to get the tomcat binary and unpack
RUN mkdir -p /opt/tomcat && \
  # We can't use the main mirror any more as they no longer contain the
  # version we want
  # curl -s http://mirror.ox.ac.uk/sites/rsync.apache.org/tomcat/tomcat-7/v7.0.56/bin/apache-tomcat-7.0.56.tar.gz | \
  curl -s https://archive.apache.org/dist/tomcat/tomcat-7/v7.0.56/bin/apache-tomcat-7.0.56.tar.gz | \
  tar zxf - --strip-components 1 -C /opt/tomcat && \
  cd /opt/tomcat && \
  rm -r webapps && \
  sed -i.orig '/^common.loader=/s@$@,${catalina.base}/common/classes/,${catalina.base}/common/lib/*.jar@;/^shared.loader=/s@$@${catalina.base}/shared/classes/,${catalina.base}/shared/lib/*.jar@;/^server.loader=/s@$@${catalina.base}/server/classes/,${catalina.base}/server/lib/*.jar@' conf/catalina.properties && \
  sed -i.orig 's/^org.apache.catalina.startup.ContextConfig.jarsToSkip=.*/org.apache.catalina.startup.ContextConfig.jarsToSkip=*.jar/' conf/catalina.properties && \
  mkdir -p shared/classes shared/lib common/classes common/lib server/classes server/lib webapps

# Override with custom server.xml
COPY server.xml /opt/tomcat/conf/server.xml

# /opt/tomcat/sakai/logs is for Apache James logging.
RUN mkdir -p /opt/scripts && \
  mkdir -p /opt/tomcat/sakai/files && \
  mkdir -p /opt/tomcat/sakai/deleted && \
  mkdir -p /opt/tomcat/sakai/logs

# The logs directory needs to be writable by tomcat
RUN chown sakai /opt/tomcat/logs /opt/tomcat/temp /opt/tomcat/work /opt/tomcat/sakai/files /opt/tomcat/sakai/deleted /opt/tomcat/sakai/logs /opt/tomcat/webapps && \
  find /opt/tomcat/conf/ -type f| xargs chmod 640 && \
  mkdir -p /opt/tomcat/conf/Catalina && chown sakai /opt/tomcat/conf/Catalina && \
  chgrp sakai -R /opt/tomcat/conf && chmod 755 /opt/tomcat/conf && \
  touch /opt/tomcat/sakai/sakai.properties && \
  chown sakai /opt/tomcat/sakai/sakai.properties

# Copy in the JCE unlimited strength policy files
RUN curl -sLO --cookie 'oraclelicense=accept-securebackup-cookie;'  http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip && \
  jar xf UnlimitedJCEPolicyJDK7.zip && \
  cp UnlimitedJCEPolicy/*.jar $JAVA_HOME/jre/lib/security && \
  rm -r UnlimitedJCEPolicyJDK7.zip UnlimitedJCEPolicy

# Setup all the logging to use log4j
# This needs to go in the lib folder
RUN curl -s -o /opt/tomcat/lib/tomcat-juli-adaptors.jar https://archive.apache.org/dist/tomcat/tomcat-7/v7.0.56/bin/extras/tomcat-juli-adapters.jar &&\
  curl -s -o /opt/tomcat/bin/tomcat-juli.jar https://archive.apache.org/dist/tomcat/tomcat-7/v7.0.56/bin/extras/tomcat-juli.jar && \
  rm /opt/tomcat/conf/logging.properties

# This sets the default locale and gets it to work correctly in Java
ENV LANG en_GB.UTF-8
RUN /usr/sbin/locale-gen $LANG

COPY ./entrypoint.sh /opt/scripts/entrypoint.sh
RUN chmod 755 /opt/scripts/entrypoint.sh

ENV CATALINA_OPTS_MEMORY -Xms256m -Xmx1024m -XX:NewSize=192m -XX:MaxNewSize=384m -XX:PermSize=192m -XX:MaxPermSize=384m

ENV CATALINA_OPTS \
# Force the JVM to run in server mode (shouldn't be necessary, but better sure ).
-server \
# Make the JVM headless so it doesn't try and use X11 at all.
-Djava.awt.headless=true \
# Stop the JVM from caching DNS lookups, otherwise we don't get DNS changes propogating
-Dsun.net.inetaddr.ttl=0 \
# https://jira.sakaiproject.org/browse/SAK-16745 says it's no longer needed, need to test
-Dsun.lang.ClassLoader.allowArraySyntax=true \
# https://jira.sakaiproject.org/browse/SAK-17425 Disable strict quoting on JSPs 
-Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false \
# If the component manager doesn't start shut down the JVM
-Dsakai.component.shutdownonerror=true \
# Force the locale
-Duser.language=en -Duser.country=GB \
# Set the properties for Sakai (sakai.home isn't necessary)
-Dsakai.home=/opt/tomcat/sakai -Dsakai.security=/opt/tomcat/sakai \
# Set the timezone as the docker container doesn't have this set
-Duser.timezone=Europe/London \
# Connect timeout (5 minutes)
-Dsun.net.client.defaultConnectTimeout=300000 \
# Read timeout (30 minutes)
-Dsun.net.client.defaultReadTimeout=1800000

# If we run in debug mode
ENV JPDA_OPTS -agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=n

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]

CMD ["/opt/tomcat/bin/catalina.sh", "run"]
