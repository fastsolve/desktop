# Builds a Docker image for FastSolve development environment
# with Ubuntu, Octave, Python3, Jupyter Notebook and VSCode.
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

FROM fastsolve/desktop:base
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

ADD image/home $DOCKER_HOME/

# Install vscode and system packages
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg && \
    sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list' && \
    \
    apt-get update && \
    apt-get install  -y --no-install-recommends \
        nano \
        vim \
        build-essential \
        pkg-config \
        gfortran \
        cmake \
        bison \
        flex \
        git \
        bash-completion \
        bsdtar \
        rsync \
        wget \
        ccache \
        \
        clang \
        clang-format \
        libboost-all-dev \
        qt5dxcb-plugin \
        code \
        diffuse \
        enchant && \
    apt-get install -y --no-install-recommends \
        python3-pip \
        python3-dev \
        python3-wheel \
        swig3.0 \
        pandoc \
        ttf-dejavu && \
    apt-get clean && \
    pip3 install -U \
        setuptools && \
    pip3 install -U \
        numpy \
        scipy \
        sympy \
        PyQt5 \
        matplotlib \
        pandas \
        numba \
        numpydoc \
        autopep8 \
        flake8 \
        yapf \
        black \
        pyenchant \
        mpi4py \
        pylint \
        cpplint \
        pytest \
        Cython \
        Sphinx \
        sphinx_rtd_theme && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    chown -R $DOCKER_USER:$DOCKER_GROUP $DOCKER_HOME

USER $DOCKER_USER
ENV  GIT_EDITOR=nano EDITOR=code
WORKDIR $DOCKER_HOME

# Install vscode extensions
RUN mkdir -p $DOCKER_HOME/.vscode && \
    mv $DOCKER_HOME/.vscode $DOCKER_HOME/.config/vscode && \
    ln -s -f $DOCKER_HOME/.config/vscode $DOCKER_HOME/.vscode && \
    git clone https://github.com/VundleVim/Vundle.vim.git \
        $DOCKER_HOME/.vim/bundle/Vundle.vim && \
    vim -c "PluginInstall" -c "quitall" && \
    python3 $DOCKER_HOME/.vim/bundle/YouCompleteMe/install.py \
        --clang-completer --system-boost && \
    bash -c 'for ext in \
        ms-vscode.cpptools \
        jbenden.c-cpp-flylint \
        foxundermoon.shell-format \
        cschlosser.doxdocgen \
        bbenoist.doxygen \
        streetsidesoftware.code-spell-checker \
        eamodio.gitlens \
        james-yu.latex-workshop \
        yzhang.markdown-all-in-one \
        davidanson.vscode-markdownlint \
        gimly81.matlab \
        krvajalm.linter-gfortran \
        ms-python.python \
        guyskk.language-cython \
        vector-of-bool.cmake-tools \
        twxs.cmake \
        shardulm94.trailing-spaces \
        ms-azuretools.vscode-docker \
        formulahendry.code-runner \
        mine.cpplint \
        formulahendry.terminal; \
        do \
            code --install-extension $ext; \
        done'

USER root
