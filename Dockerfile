# Builds a Docker image for FastSolve development environment
# with Ubuntu 16.04, Octave, Python3, Jupyter Notebook and Atom
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

FROM fastsolve/desktop:latest
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

# Install debugging tools and Atom
RUN add-apt-repository ppa:webupd8team/atom && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        meld \
        atom \
        clang-format && \
    curl -L https://goo.gl/ExjLDP | bsdtar zxf - -C /usr/local --strip-components 2 && \
    ln -s -f /usr/local/MATLAB/R2017a/bin/glnxa64/mlint /usr/local/bin && \
    apt-get clean && \
    pip3 install -U \
         autopep8 \
         flake8 \
         PyQt5 \
         spyder && \
    rm -rf /var/lib/apt/lists/* && \
    apm install \
        language-cpp14 \
        language-matlab \
        language-fortran \
        language-docker \
        autocomplete-python \
        autocomplete-fortran \
        git-plus \
        merge-conflicts \
        split-diff \
        gcc-make-run \
        platformio-ide-terminal \
        intentions \
        busy-signal \
        linter-ui-default \
        linter \
        linter-gcc \
        linter-gfortran \
        linter-flake8 \
        linter-matlab \
        dbg \
        output-panel \
        dbg-gdb \
        python-debugger \
        auto-detect-indentation \
        python-autopep8 \
        clang-format && \
    chown -R $DOCKER_USER:$DOCKER_GROUP $DOCKER_HOME

USER $DOCKER_USER

# Clone ilupack4m, paracoder, and petsc4m
RUN rm -f $DOCKER_HOME/.octaverc && \
    mkdir -p $DOCKER_HOME/fastsolve && \
    cd $DOCKER_HOME/fastsolve && \
    git clone https://github.com/fastsolve/ilupack4m && \
    cd ilupack4m/makefiles && make TARGET=Octave && \
    \
    cd $DOCKER_HOME/fastsolve && \
    git clone https://github.com/fastsolve/paracoder && \
    cd paracoder && octave --eval "build_m2c -force" && \
    \
    cd $DOCKER_HOME/fastsolve && \
    git clone https://github.com/fastsolve/petsc4m && \
    cd petsc4m && octave --eval "build_petsc -force" && \
    \
    echo "addpath $DOCKER_HOME/fastsolve/ilupack4m/matlab/ilupack" > $DOCKER_HOME/.octaverc && \
    echo "run $DOCKER_HOME/fastsolve/paracoder/.octaverc" >> $DOCKER_HOME/.octaverc && \
    echo "run $DOCKER_HOME/fastsolve/petsc4m/.octaverc" >> $DOCKER_HOME/.octaverc && \
    echo "@octave --force-gui" >> $DOCKER_HOME/.config/lxsession/LXDE/autostart && \
    echo "@atom $DOCKER_HOME/fastsolve" >> $DOCKER_HOME/.config/lxsession/LXDE/autostart && \
    chown -R $DOCKER_USER:$DOCKER_GROUP $DOCKER_HOME

WORKDIR $DOCKER_HOME/fastsolve
USER root
