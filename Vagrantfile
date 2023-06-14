# -*- mode: ruby -*
# vi: set ft=ruby

require 'fileutils'

def ansible_playbook(instance, limit=nil, name='setup', tags=nil, playbook='./provision.yml')
    limit ||= 'all'

    instance.vm.provision name, type: "ansible" do |ansible|
        ansible.playbook          = playbook
        ansible.config_file       = "ansible.cfg"
        ansible.galaxy_role_file  = "./roles/requirements.yml"
        ansible.galaxy_roles_path = "./roles"
        ansible.galaxy_command    = "ansible-galaxy install --role-file=%{role_file} --roles-path=%{roles_path}"
        if File.file?("#{ENV['HOME']}/.vagrant.d/vault_password_files.d/provision.txt") then
            ansible.vault_password_file = "#{ENV['HOME']}/.vagrant.d/vault_password_files.d/provision.txt"
        else
            ansible.ask_vault_pass = true
        end
        ansible.groups = {
            "server" => ["test19-server"],
            "client" => ["test19-client"]
        }
        ansible.limit = limit
        unless tags.nil? || tags == ''
            ansible.tags  = tags
        end
    end
end

Vagrant.configure("2") do |config|
    config.vm.box_check_update = true
    vbox_default_vm_folder_path = `vboxmanage list systemproperties | grep machine | cut -d':' -f2 | awk '{print $1}'`
    vbox_default_vm_folder_path = vbox_default_vm_folder_path.sub("VirtualBox", "VirtualBoxDisk")

    provision_vm = <<-SCRIPT
        apt update
        apt install -y python3
    SCRIPT

    machines=[ {
        :box => "generic/ubuntu2204",
        :hostname => "awx-test-client",
        :ip => "192.168.59.213",
        :shell => provision_vm,
        :ssh => [ {
            :ssh_key_path => "id_rsa_files",
            :ssh_key_name => "id_rsa",
            :key_type => "rsa",
            :bit => 4096
        } ]
        }
    ]

    machines.each do |machine|
        config.trigger.before :up do |trigger|
            trigger.name = "Running #{machine[:hostname]} VM trigger"
            trigger.ruby do
                if (machine[:disk].is_a?(Array))
                    disk_path = File.join("#{vbox_default_vm_folder_path.chomp}", "#{machine[:hostname].sub("-","_")}", "disks")
                    FileUtils.mkdir_p(disk_path) unless File.directory?(disk_path)
                end
            end
        end
        config.trigger.after :destroy do |trigger|
            trigger.name = "Running #{machine[:hostname]} VM trigger"
            trigger.ruby do
                if (machine[:disk].is_a?(Array))
                    disk_path = File.join("#{vbox_default_vm_folder_path.chomp}", "#{machine[:hostname].sub("-","_")}")
                    FileUtils.rm_rf(disk_path)
                end
                if (machine[:ssh].is_a?(Array))
                    machine[:ssh].each do |s|
                        FileUtils.rm_rf(s[:ssh_key_path])
                    end
                end
                FileUtils.rm_rf("roles")
                FileUtils.rm_rf("ansible.log")
            end
        end

        config.vm.define machine[:hostname] do |node|
            post_up_message = "Machine already provisioned. Run `vagrant provision #{machine[:hostname]}`\n" \
                            + "sudo echo '#{machine[:ip]}  #{machine[:hostname]}' | sudo tee -a /etc/hosts\n" \
                            + "The machine domain address: http://#{machine[:hostname]}/\n" \
                            + "The machine IP address: http://#{machine[:ip]}"

            node.vm.box = machine[:box]
            node.vm.hostname = machine[:hostname]
            node.vm.network "private_network", ip: machine[:ip], auto_config: true, virtualbox_intnet: true

            if (machine[:port].is_a?(Array))
                machine[:port].each do |p|
                    node.vm.network :forwarded_port, guest: "#{p[:guest]}", host: "#{p[:host]}"
                    node.vm.post_up_message = post_up_message \
                                            + ":#{p[:guest]}/"
                end
            else
                node.vm.post_up_message = post_up_message \
                                        + "/"
            end
            if (machine[:sync].is_a?(Array))
                machine[:sync].each do |s|
                    node.vm.synced_folder "#{s[:src]}", "#{s[:dst]}"
                end
            end
            if (machine[:file].is_a?(Array))
                machine[:file].each do |f|
                    node.vm.provision "file", source: "#{f[:src]}", destination: "#{f[:dst]}"
                end
            end
            if (machine[:ansible].is_a?(Array))
                machine[:ansible].each do |a|
                    ansible_playbook(instance=node, limit="#{a[:limit]}")
                end
            end
            if (machine[:ssh].is_a?(Array))
                machine[:ssh].each do |sh|
                    FileUtils.mkdir_p(sh[:ssh_key_path]) unless File.directory?(sh[:ssh_key_path])
                    system("ssh-keygen -q -t #{sh[:key_type]} -b #{sh[:bit]} -N \'\' -f #{sh[:ssh_key_path]}/#{sh[:ssh_key_name]}") unless File.exists?("#{sh[:ssh_key_path]}/#{sh[:ssh_key_name]}")
                    node.vm.provision "shell" do |s|
                        if(File.directory?(sh[:ssh_key_path]))
                            ssh_pub_key = File.readlines("#{sh[:ssh_key_path]}/#{sh[:ssh_key_name]}.pub").first.strip
                            s.inline = "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
                        end
                    end
                end
            end

            node.vm.provision "shell", inline: "#{machine[:shell]}" unless not machine [:shell].is_a?(String)
            node.vm.provision "shell", path: "#{machine[:script]}" unless not machine [:script].is_a?(String)

            node.vm.provider "virtualbox" do |vbox|
                vbox.name = machine[:hostname]
                vbox.linked_clone = true
                vbox.default_nic_type = "virtio"
                if (machine[:resource_limit].is_a?(Array) and machine[:resource_limit].length() == 1)
                        machine[:resource_limit].each do |resource|
                            vbox.memory = resource[:memory]
                            vbox.cpus = resource[:cpu]
                        end
                end

                if (machine[:disk].is_a?(Array) and !File.directory?(File.join("#{vbox_default_vm_folder_path.chomp}", "#{machine[:hostname].sub("-","_")}")))
                    vbox.customize ['storagectl', :id, '--name', 'Virtual I/O Device SCSI controller', '--add', 'virtio-scsi', '--portcount', machine[:disk].length()]
                    machine[:disk].each_with_index do |d, index|
                        disk_file_name = "disk-#{index}.vdi"
                        disk_file_path = File.join("#{vbox_default_vm_folder_path.chomp}", "#{machine[:hostname].sub("-","_")}", "disks", "#{disk_file_name}")
                        vbox.customize ['createhd', '--filename', disk_file_path, '--variant', d[:disk_type], '--size', d[:disk_size]*1024] unless File.exists?(disk_file_path)
                        vbox.customize ['storageattach', :id, '--storagectl', 'Virtual I/O Device SCSI controller', '--port', index, '--device', 0, '--type', 'hdd', '--medium', disk_file_path]
                    end
                end
            end
        end
    end
end