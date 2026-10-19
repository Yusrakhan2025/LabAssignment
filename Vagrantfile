
Vagrant.configure("2") do |config|
  # Use the instructor-approved box if supplied through VAGRANT_BOX.
  config.vm.box = ENV.fetch("VAGRANT_BOX", "ubuntu/jammy64")

  # Forward host port 8080 to guest port 80.
  config.vm.network "forwarded_port",
    guest: 80,
    host: 8080,
    auto_correct: true

  # VirtualBox resources.
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 1024
    vb.cpus = 1
  end

  # Automatically run the provisioning script.
  config.vm.provision "shell",
    path: "provision.sh",
    privileged: true
end
