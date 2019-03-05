module VagrantPlugins
  module Ignition
    module Action
      class Clean
        def initialize(app, env)
          @app = app
          # env[:machine].ui.info "Ignition Clean init..."
        end

        def get_vm_info(env)
          info = env[:machine].provider.driver.execute("showvminfo", env[:machine].id, "--machinereadable", retryable: true)
          return info.split("\n")
        end

        def get_hd_uuid(vminfo) 
          vminfo.each do |line|
            if hd_uuid = line[/^"IDE Controller-ImageUUID-1-0"=\"(.*)\"/i, 1]
              return hd_uuid
            end
          end

          nil
        end

        def call(env)
          @env = env
          env[./:machine].ui.info "Running Ignition Clean..."

          if env[:machine].config.ignition.enabled == false
            @app.call(env)
            return
          end

          if env[:machine].config.ignition.remove_after_provision == true && !env[:machine].id.nil? && env[:machine].id != ""
            
            vminfo = get_vm_info(env)
            hd_uuid = get_hd_uuid(vminfo)
            
            env[:machine].ui.info "Detaching IDE Controller-1-0..."
            begin
              env[:machine].provider.driver.execute("storageattach", "#{env[:machine].id}", "--storagectl", "IDE Controller", "--device", "0", "--port", "1", "--type", "hdd", "--medium", "none")
            rescue Vagrant::Errors::VBoxManageError => e
              env[:machine].ui.warn("(error while detaching media = #{e.inspect})")
            end
            
            env[:machine].ui.info "Removing IDE Controller-1-0 (#{hd_uuid})..."
            begin
              env[:machine].provider.driver.execute("closemedium","disk",hd_uuid,"--delete")
            rescue Vagrant::Errors::VBoxManageError => e
              env[:machine].ui.warn("(error while removing media = #{e.inspect})")
            end

          end
          # Continue through the middleware chain
          @app.call(env)
        end
      end
    end
  end
end
