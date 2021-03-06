require 'delegate'

class Rufus::LockingIODecorator < SimpleDelegator

  class Guard
    def sync
      lock_file.flock(File::LOCK_EX) # acquire exclusive lock
      yield
    ensure
      lock_file.flock(File::LOCK_UN) # release lock
    end


    private

    def lock_file
      # the lock file needs to be the same across all processes of this group,
      # but the file handle needs to be unique per thread and process
      Thread.current["#{self.class.name}::#{Process.pid}"] ||=
        File.new(lock_file_path, 'w')
    end

    def lock_file_path
      "/tmp/rufus-runner.#{Process.getpgrp}.lock"
    end
  end


  def initialize(*)
    @guard = Guard.new
    super
  end

  def write(*args)
    @guard.sync do
      __getobj__.write(*args)
    end
  end

  def puts(*args)
    @guard.sync do
      __getobj__.puts(*args)
    end
  end

  def print(*args)
    @guard.sync do
      __getobj__.print(*args)
    end
  end

end
