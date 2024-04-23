FROM ubuntu:22.04
LABEL org.opencontainers.image.authors="Argo triwidodo"
# Jenkins Vesion
ARG VERSION=4.9

# setup jmeter version to use
ARG JMETER_VERSION="5.5"
ARG JMETER_PLUGINS_MANAGER_VERSION="1.8"
ARG CMDRUNNER_VERSION="2.3"
ENV JMETER_HOME /opt/apache-jmeter-${JMETER_VERSION}
ENV JMETER_BIN  ${JMETER_HOME}/bin
ENV MIRROR_HOST https://archive.apache.org/dist/jmeter
ENV JMETER_DOWNLOAD_URL ${MIRROR_HOST}/binaries/apache-jmeter-${JMETER_VERSION}.tgz
ENV JMETER_PLUGINS_DOWNLOAD_URL https://repo1.maven.org/maven2/kg/apc
ENV JMETER_PLUGINS_FOLDER ${JMETER_HOME}/lib/ext/
ENV JMETER_INFLUX_PLUGIN_JAR_URL https://github.com/mderevyankoaqa/jmeter-influxdb2-listener-plugin/releases/download/v2.6/jmeter-plugins-influxdb2-listener-2.6.jar
ENV PATH $PATH:$JMETER_BIN

# Set Jenkins Group
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Make sure the package repository is up to date.
#RUN add-apt-repository ppa:openjdk-r/ppa
RUN apt-get update
RUN apt-get -y upgrade
# RUN apt-get install -y build-essential

# Install a basic SSH server
RUN apt install -y openssh-server
RUN sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd
RUN mkdir -p /var/run/sshd

# Install Open JDK 17 (latest edition) and other tools
RUN apt install -y openjdk-17-jdk && apt install -y curl unzip wget git


# Add user jenkins to the image
RUN adduser --quiet jenkins
RUN usermod -a -G root jenkins

# Change Timezone To jakarta
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata
RUN echo "Asia/Jakarta" > /etc/timezone
RUN dpkg-reconfigure -f noninteractive tzdata
RUN date

# Download Jenkins slave
RUN curl --create-dirs -fsSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar

# Install Jmeter Needed.
RUN \
  sed -i -e 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends build-essential && \
  apt-get install -y --no-install-recommends software-properties-common && \
  apt-get install -y --no-install-recommends byobu openjdk-11-jre curl git htop man unzip vim wget python3-pip && \
  mkdir -p /tmp/dependencies &&   \
  curl -L --silent ${JMETER_DOWNLOAD_URL} >  /tmp/dependencies/apache-jmeter-${JMETER_VERSION}.tgz &&  \
  mkdir -p /opt && \
  tar -xzf /tmp/dependencies/apache-jmeter-${JMETER_VERSION}.tgz -C /opt &&  \
  rm -rf /tmp/dependencies && \
  rm -rf /var/lib/apt/lists/*
# Install jmeter lib and dependency jars
RUN curl -L --silent ${JMETER_PLUGINS_DOWNLOAD_URL}/jmeter-plugins-manager/${JMETER_PLUGINS_MANAGER_VERSION}/jmeter-plugins-manager-${JMETER_PLUGINS_MANAGER_VERSION}.jar -o ${JMETER_PLUGINS_FOLDER}/jmeter-plugins-manager-${JMETER_PLUGINS_MANAGER_VERSION}.jar
RUN curl -L --silent ${JMETER_PLUGINS_DOWNLOAD_URL}/cmdrunner/${CMDRUNNER_VERSION}/cmdrunner-${CMDRUNNER_VERSION}.jar -o ${JMETER_HOME}/lib/cmdrunner-${CMDRUNNER_VERSION}.jar && \
    curl -L --silent ${JMETER_INFLUX_PLUGIN_JAR_URL} -o ${JMETER_PLUGINS_FOLDER}/jmeter-plugins-influxdb2-listener-2.6.jar && \
    java -cp ${JMETER_PLUGINS_FOLDER}/jmeter-plugins-manager-${JMETER_PLUGINS_MANAGER_VERSION}.jar org.jmeterplugins.repository.PluginManagerCMDInstaller && \
    PluginsManagerCMD.sh install jpgc-cmd=2.2,jpgc-casutg=2.10,jpgc-dummy=0.4,jpgc-filterresults=2.2,jpgc-synthesis=2.2,jpgc-graphs-basic=2.0 \
    && jmeter --version \
    && PluginsManagerCMD.sh status \
# Set password for the jenkins user (you may want to alter this).
RUN echo "jenkins:jenkins" | chpasswd
WORKDIR /home/jenkins

RUN chown -R jenkins:jenkins /home/jenkins/.m2/
# Standard SSH port
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]