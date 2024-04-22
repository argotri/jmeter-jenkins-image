FROM ubuntu:22.04
LABEL org.opencontainers.image.authors="Argo triwidodo"

ARG VERSION=4.9
# For Jmeter Instalation
ARG JMETER_VERSION="5.5"
ARG CMDRUNNER_JAR_VERSION="2.2"
ARG JMETER_PLUGINS_MANAGER_VERSION="1.7"

# Set environment variables
ENV JMETER_HOME /opt/jmeter
ENV JMETER_LIB_FOLDER ${JMETER_HOME}/lib/
ENV JMETER_PLUGINS_FOLDER ${JMETER_LIB_FOLDER}ext/
ENV JMETER_BIN  ${JMETER_HOME}/bin
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


# Install Maven
RUN apt-get install -y maven

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

# Start Instalation jmeter Image
RUN mkdir ${JMETER_HOME}
RUN mkdir ${JMETER_LIB_FOLDER}
RUN mkdir ${JMETER_PLUGINS_FOLDER}
WORKDIR ${JMETER_HOME}


# Set password for the jenkins user (you may want to alter this).
RUN echo "jenkins:jenkins" | chpasswd
RUN mkdir /home/jenkins/.m2
#ADD settings.xml /home/jenkins/.m2/
RUN chown -R jenkins:jenkins /home/jenkins/.m2/
# Standard SSH port
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]