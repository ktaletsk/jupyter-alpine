FROM alpine
MAINTAINER team@nb.gallery

########################################################################
# Set up OS
########################################################################

EXPOSE 80 443
WORKDIR /root

ENV CPPFLAGS=-s \
    SHELL=/bin/bash

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["jupyter", "notebook"]

COPY util/* /usr/local/bin/
COPY config/bashrc /root/.bashrc
COPY patches /root/.patches
COPY config/repositories /etc/apk/repositories
COPY config/team@jupyter.gallery-576b3ab3.rsa.pub /etc/apk/keys/

RUN \
  min-apk \
    bash \
    bzip2 \
    curl \
    file \
    gcc \
    g++ \
    git \
    libressl \
    make \
    openssh-client \
    patch \
    readline-dev \
    tar \
    tini && \
  echo "### Install specific version of zeromq from source" && \
  min-package https://archive.org/download/zeromq_4.0.4/zeromq-4.0.4.tar.gz && \
  ln -s /usr/local/lib/libzmq.so.3 /usr/local/lib/libzmq.so.4 && \
  strip --strip-unneeded --strip-debug /usr/local/bin/curve_keygen && \
  echo "### Alpine compatibility patch for various packages" && \
  if [ ! -f /usr/include/xlocale.h ]; then echo '#include <locale.h>' > /usr/include/xlocale.h; fi && \
  echo "### Cleanup unneeded files" && \
  clean-terminfo && \
  rm /bin/bashbug && \
  rm /usr/local/share/man/*/zmq* && \
  rm -rf /usr/include/c++/*/java && \
  rm -rf /usr/include/c++/*/javax && \
  rm -rf /usr/include/c++/*/gnu/awt && \
  rm -rf /usr/include/c++/*/gnu/classpath && \
  rm -rf /usr/include/c++/*/gnu/gcj && \
  rm -rf /usr/include/c++/*/gnu/java && \
  rm -rf /usr/include/c++/*/gnu/javax && \
  rm /usr/libexec/gcc/x86_64-alpine-linux-musl/*/cc1obj && \
  rm /usr/bin/gcov* && \
  rm /usr/bin/gprof && \
  rm /usr/bin/*gcj


########################################################################
# Install Python2 & Jupyter
########################################################################

COPY config/jupyter /root/.jupyter/

RUN \
  min-apk \
    libffi-dev \
    py2-pygments \
    py2-cffi \
    py2-cryptography \
    py2-decorator \
    py2-enum34 \
    py2-jinja2 \
    py2-openssl \
    py2-pexpect \
    py2-pip \
    py2-tornado \
    python \
    python-dev && \
  pip install --no-cache-dir --upgrade setuptools pip && \
  mkdir -p `python -m site --user-site` && \
  min-pip jupyter ipywidgets && \
  jupyter nbextension enable --py --sys-prefix widgetsnbextension && \
  echo "### Cleanup unneeded files" && \
  rm -rf /usr/lib/python2*/*/tests && \
  rm -rf /usr/lib/python2*/ensurepip && \
  rm -rf /usr/lib/python2*/idlelib && \
  rm /usr/lib/python2*/distutils/command/*exe && \
  rm -rf /usr/share/man/* && \
  clean-pyc-files /usr/lib/python2* && \
  echo "### Apply patches" && \
  cd / && \
  patch -p0 < /root/.patches/ipywidget_notification_area && \
  patch -p0 < /root/.patches/ipykernel_displayhook && \
  patch -p0 < /root/.patches/websocket_keepalive

########################################################################
# Install ipydeps
########################################################################

RUN \
  pip install http://github.com/nbgallery/pypki2/tarball/master#egg=pypki2 && \
  pip install http://github.com/nbgallery/ipydeps/tarball/master#egg=ipydeps && \
  echo TODO: applying workaround for https://github.com/nbgallery/ipydeps/issues/7 && \
  sed -i 's/packages = list(set(packages)/#packages = list(set(packages)/' /usr/lib/python2*/site-packages/ipydeps/__init__.py
	
########################################################################
# Add dynamic kernels
########################################################################

ADD kernels /usr/share/jupyter/kernels/
ENV JAVA_HOME=/usr/lib/jvm/default-jvm \
    SPARK_HOME=/usr/spark
ENV PATH=$PATH:$JAVA_HOME/bin:$SPARK_HOME/bin:/usr/share/jupyter/kernels/installers

########################################################################
# Add Bash kernel
########################################################################

RUN \
  min-pip bash_kernel && \
  python -m bash_kernel.install && \
  clean-pyc-files /usr/lib/python2*

########################################################################
# Metadata
########################################################################

LABEL gallery.nb.version="4.4.1" \
      gallery.nb.description="Minimal alpine-based Jupyter notebook server" \
      gallery.nb.URL="https://github.com/nbgallery"
