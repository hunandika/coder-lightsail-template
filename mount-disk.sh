sudo su - coder
echo "attach disk workspaces starting"
sudo file -s /dev/nvme1n1
sudo mount /dev/nvme1n1 /home/coder/workspaces
sudo cp /etc/fstab /etc/fstab.orig
sudo echo '/dev/nvme1n1 /home/coder/workspaces ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
sudo chown coder:coder /home/coder/workspaces
sudo chmod 755 /home/coder/workspaces
echo "attach disk workspaces finish"