# frozen_string_literal: true

###
# These tests assume that the container has a defined command that stays running indefinitely.
# If the container runs a command without a wait loop, you'll have to redefine the whole testing procedure.

desc 'Test docker/podman images'
task :test do
  # check that the build system is available
  build_system = Builder.new.runtime?
  unless build_system.running?
    puts "#{build_system.name} is not running: sanity check failed.".red
    exit 1
  end
  
  puts '*** Testing images ***'.green
  $images.each do |image|
    next unless image.test_image?
    
    # basic container test
    begin
      build_tag = image.build_name_tag
      puts "Image: #{build_tag}".pink

      container = `#{build_system.name.downcase} run --mount=type=bind,source=./resources/,destination=/tmp/tomcat/,z -e BASE_URL=file:///tmp/tomcat/catalina_base.tgz -e WAR_URL=file:///tmp/tomcat/ROOT.war --health-interval=2s -d #{build_tag} #{image.test_command}`.strip

      # abort if container didn't get created
      unless $?.success?
        puts "Container failed to start.".red
        exit 1
      end

      # wait for container state "running"
      state = ''
      exitcode = nil
      error = nil

      printf 'Waiting for container startup'
      10.times do
        state = `#{build_system.name.downcase} inspect --format='{{.State.Status}}' #{container}`.strip
        exitcode = `#{build_system.name.downcase} inspect --format='{{.State.ExitCode}}' #{container}`.strip
        error = `#{build_system.name.downcase} inspect --format='{{.State.Error}}' #{container}`.strip
        exit 1 unless $?.success?
        break if state == 'running'

        # if the docker container exited cleanly, it can't be tested, but that may be expected
        if state == 'exited' && exitcode == '0'
          puts "\nContainer entrypoint or command exited cleanly. This container doesn't stay running without arguments, so it needs a custom test, or set test_command to \"sleep infinity\" for an infinite sleep.".yellow
          break
        elsif state == 'exited'
          puts "Container failed to reach \"running\" state. Got \"#{state}\"".red
          puts "Container exit code: #{exitcode}".yellow
          puts "Container error message: #{error}".yellow
          puts '--- begin container logs ---'.yellow
          puts `#{build_system.name.downcase} logs #{container}`
          puts '--- end container logs ---'.yellow
          exit 1
        end

        printf '.'
        sleep 1
      end
      puts # end of progress dots

      # if the container has a health check, wait up to 20 seconds for it to be successful
      container_health = `#{build_system.name.downcase} inspect --format='{{.State.Health}}' #{container}`.strip
      hashealth = container_health != '<nil>'
      if hashealth
        printf 'Waiting for container healthy'
        health_status = ''
        20.times do
          health_status = `#{build_system.name.downcase} inspect --format='{{.State.Health.Status}}' #{container}`.strip
          exit 1 unless $?.success?
          break if health_status == 'healthy'

          printf '.'
          sleep 1
        end
        puts
        if health_status != 'healthy'
          puts "Container failed to reach \"healthy\" status. Got \"#{health_status}\"".red
          exit 1
        end
      end
      # end of basic container test

      ###
      # put your custom image tests here
      ###

      # end of container tests
    ensure
      sh "#{build_system.name.downcase} kill #{container}" if `#{build_system.name.downcase} inspect --format='{{.State.Status}}' #{container}`.strip == 'running'
      sh "#{build_system.name.downcase} rm #{container}"
    end
    puts "Testing image #{image.build_tag} successful.".green
  end
end
