module Pulso

  class Folder

    attr_reader :name,:timestamp

    def initialize name
      @name = name
      @timestamp = Time.at 0
    end

  end

  class Data
    
    attr_reader :name, :data, :timestamp

    def initialize name, object
      @name = name
      @data = object
      @timestamp = Time.now
    end


  end

  class BlackBoard

    require 'rubygems'
    require 'memcache'

    @cache = nil

    attr_reader :topic

    def initialize topic, opts = {}
      @topic = topic
      @folders = {}
      servers = opts[:servers]
      servers ||= "127.0.0.1:11411"

      @cache = MemCache.new servers, :namespace => topic
    end

    def active?
      @cache.active?
    end

    def has_folders?
      !@folders.empty?
    end

    def empty?
      @cache.stats.inject(0) {|sum, server| sum + server.last["curr_items"]} == 0
    end

    def add_folder name
      folder = Pulso::Folder.new :folder1
      @folders[name] = folder
    end

    def folders
      @folders.keys
    end

    def add folder, object
      id = "#{folder.to_s}#{object.name.to_s}".to_sym
      @cache[id] = object
    end

    def get folder, obj_name
      id = "#{folder.to_s}#{obj_name.to_s}".to_sym
      @cache[id]
    end


=begin
    def clean
      @cache.flush_all
    end

    def write obj
      @cache["#{obj.name}#{obj.arguments}"] = obj
    end

    def read method, arguments
      @cache["#{method}#{arguments}"]
    end

=end
  end

end
