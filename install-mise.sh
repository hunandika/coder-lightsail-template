sudo su - coder
echo "Install MISE..."
curl https://mise.run | sh

echo "Activate MISE in the current shell session"
echo 'export MISE_CONFIG_DIR=$HOME/workspaces/.config/mise' >> ~/.bashrc
echo 'export MISE_CACHE_DIR=$HOME/workspaces/.cache/mise' >> ~/.bashrc
echo 'export MISE_STATE_DIR=$HOME/workspaces/.local/state/mise' >> ~/.bashrc
echo 'export MISE_DATA_DIR=$HOME/workspaces/.local/share/mise' >> ~/.bashrc
echo 'export CLOUDSDK_CONFIG=$HOME/workspaces/.config/gcloud' >> ~/.bashrc
echo 'export KUBECONFIG=$HOME/workspaces/.kube/config' >> ~/.bashrc
echo 'export XDG_CACHE_HOME=$HOME/workspaces' >> ~/.bashrc

echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

~/.local/bin/mise --version
~/.local/bin/mise ls
echo "Configure MISE Done...! Happy Coding!!!"
