# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/vivid64"
  config.vm.provision "shell", inline: <<-SHELL
    apt-get -y update
    apt-get -y install git bundler ruby graphviz
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    git clone https://github.com/anaynayak/aws-security-viz.git
    cd aws-security-viz
    bundle install
    # bundle exec ruby lib/visualize_aws.rb -a your_aws_key -s your_aws_secret_key -f viz.svg --color=true
  SHELL
end
