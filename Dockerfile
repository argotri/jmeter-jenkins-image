FROM ubuntu:23.10
LABEL org.opencontainers.image.authors="Argo triwidodo"
# Jenkins Vesion
ARG VERSION=4.9

# setup jmeter version to use
ARG JMETER_VERSION="5.3"
ARG CMDRUNNER_JAR_VERSION="2.2.1"
ARG JMETER_PLUGINS_MANAGER_VERSION="1.6"
ENV JMETER_HOME /opt/apache-jmeter-${JMETER_VERSION}
ENV JMETER_LIB_FOLDER ${JMETER_HOME}/lib/
ENV JMETER_PLUGINS_FOLDER ${JMETER_LIB_FOLDER}ext/
ENV MIRROR_URL https://archive.apache.org/dist/jmeter/binaries/
ENV JMETER_INFLUX_PLUGIN_JAR_URL https://github.com/mderevyankoaqa/jmeter-influxdb2-listener-plugin/releases/download/v2.6/jmeter-plugins-influxdb2-listener-2.6.jar

# Set Jenkins Group
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Make sure the package repository is up to date.
#RUN add-apt-repository ppa:openjdk-r/ppa
RUN apt-get update
# RUN apt-get -y upgrade
# RUN apt-get install -y build-essential

# Install a basic SSH server
RUN apt install -y openssh-server
RUN sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd
RUN mkdir -p /var/run/sshd

# Install Open JDK 11 and other tools
RUN apt install -y openjdk-11-jdk && apt install -y curl unzip wget git
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:${PATH}:${JMETER_HOME}/bin"
#Install Jmeter
WORKDIR ${JMETER_HOME}
RUN apt-get install -y wget gnupg
RUN wget ${MIRROR_URL}/apache-jmeter-${JMETER_VERSION}.tgz
RUN tar -xzf apache-jmeter-${JMETER_VERSION}.tgz
RUN mv apache-jmeter-${JMETER_VERSION}/* /opt/apache-jmeter-${JMETER_VERSION}
RUN rm -r /opt/apache-jmeter-${JMETER_VERSION}/apache-jmeter-${JMETER_VERSION}

# Download Command Runner and move it to lib folder
WORKDIR ${JMETER_LIB_FOLDER}
RUN wget https://repo1.maven.org/maven2/kg/apc/cmdrunner/${CMDRUNNER_JAR_VERSION}/cmdrunner-${CMDRUNNER_JAR_VERSION}.jar

# Download JMeter Plugins manager and move it to lib/ext folder
WORKDIR ${JMETER_PLUGINS_FOLDER}
RUN wget https://repo1.maven.org/maven2/kg/apc/jmeter-plugins-manager/${JMETER_PLUGINS_MANAGER_VERSION}/jmeter-plugins-manager-${JMETER_PLUGINS_MANAGER_VERSION}.jar
WORKDIR ${JMETER_LIB_FOLDER}
RUN curl -L --silent ${JMETER_INFLUX_PLUGIN_JAR_URL} -o ${JMETER_PLUGINS_FOLDER}/jmeter-plugins-influxdb2-listener-2.6.jar
COPY groovy-all-2.4.16.jar ${JMETER_PLUGINS_FOLDER}/groovy-all-2.4.16.jar
COPY mongo-java-driver-3.12.10.jar ${JMETER_PLUGINS_FOLDER}/mongo-java-driver-3.12.10.jar
COPY postgresql-42.7.3.jar ${JMETER_PLUGINS_FOLDER}/postgresql-42.7.3.jar
RUN java  -jar cmdrunner-2.2.1.jar --tool org.jmeterplugins.repository.PluginManagerCMD install-all-except jpgc-hadoop,jpgc-oauth,ulp-jmeter-autocorrelator-plugin,ulp-jmeter-videostreaming-plugin,ulp-jmeter-gwt-plugin,tilln-iso8583

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

# Set password for the jenkins user (you may want to alter this).
RUN echo "jenkins:jenkins" | chpasswd
RUN mkdir /home/jenkins/.m2
WORKDIR /home/jenkins
#ADD settings.xml /home/jenkins/.m2/
RUN chown -R jenkins:jenkins /home/jenkins/.m2/
# Standard SSH port
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
