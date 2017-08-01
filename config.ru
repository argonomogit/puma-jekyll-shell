require "jekyll"
require "yaml"

class JekyllMagic

  # Power-up sequence of JekyllMagic
  def initialize()
    ppid = Process.pid # Capture the parent process ID (for kill detection)
    cpid = fork do # Fork Jekyll build watcher, keeps from locking Puma
      Jekyll::Commands::Build.process({watch: true}) # Start Jekyll build watcher
    end

    # If you add a Gem, change the Jekyll config, or notice the builder has crashed
    # you will need to restart Puma.

    # However, since we forked the builder, it will create a zombie process when going through
    # the pkill method of restarting Puma. This will additionally prevent Puma from starting again
    # as it will still be waiting for Jekyll builder to stop.

    # To solve this, the next fork will create a lookout for a zombied process.

    fork do
      begin
        loop do
          Process.getpgid(ppid) # Check that the parent process ID still returns a status
            # This will cause an exception if the ppid is no longer running
          sleep(3) # 3 second delay timer
        end
      rescue
          # How did we get here? Either the sleep was called with the wrong number of arguments,
          # Or more likely the parent process no longer exits

          Process.kill 9, cpid # Kill our Jekyll build process
          sleep(1) # Wait for shutdown
          File.write("tmp/restart.txt", "") # Trigger a secondary rack restart just in case
      end
    end

  end


  # Under normal conditions, this is a super skinny rack app to serve our static files
  def call(env)
    [
      200,
      {
        'Content-Type'  => 'text/html',
        'Cache-Control' => 'public, max-age=86400'
      },
      File.open('public/index.html', File::RDONLY) # By default serve our index.html file
    ]
  end
end

# Create a new instance of JekyllMagic and run it
app = JekyllMagic.new
run app