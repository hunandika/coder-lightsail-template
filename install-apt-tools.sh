echo "configuring tools starting"
sudo su - coder
sudo apt install -y \
    openvpn \
    jq \
    build-essential \
    curl \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libxmlsec1-dev \
    llvm \
    make \
    tk-dev \
    wget \
    xz-utils \
    zlib1g-dev

# config aliases
echo -e "\nif [ -f ~/workspaces/.bash_aliases ]; then\n    . ~/workspaces/.bash_aliases\nfi" >> ~/.bashrc
echo "configuring tools finish"
