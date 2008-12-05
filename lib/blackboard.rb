module Pulso

  class Folder

    attr_reader :name, :timestamp, :keys

    def initialize name, keys
      @name = name
      @keys = {}
      keys.each do |key|
        @keys["#{name.to_i}#{key.to_i}"] = key
      end

      @timestamp = Time.at 0
    end

  end

  class Data
    
    attr_reader :name, :data, :timestamp

    def initialize name, object
      @name = name
      raise BlackBoardError, "Object does not have timestamp" unless object.respond_to?(:timestamp)
      @data = object
      @timestamp = Time.now
    end

  end

  class BlackBoard

    require 'rubygems'
    require 'memcache'

    @cache = nil

    attr_reader :topic, :folders

    def initialize opts = {}
      @folders = {}
      @ttl = opts[:ttl] || 2
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

    def empty? #cycle servers
      @cache.stats.inject(0) {|sum, server| sum + server.last["curr_items"]} == 0
    end

    def add_folder name, keys
      folder = Pulso::Folder.new name, keys
      @folders[name] = folder
    end

    def add folder, tag, object
      id = "#{folder.to_i}#{tag.to_i}"
      @cache.add id, Pulso::Data.new(tag, object), @ttl
    end

    def get folder, obj_name
      raise BlackBoardError, "Folder #{folder} not found" unless @folders.has_key?(folder)
        id = "#{folder.to_i}#{obj_name.to_i}"
        return unless @cache[id]
        @cache[id].data
    end

    def get_folder folder
      ret = {}
      folder = @folders[folder]
      @cache.get_multi(*folder.keys.keys).each do |k,v|
          ret.store folder.keys[k], v.data
        end
      ret
    end

    def clean
      @cache.flush_all
    end

  end

  class BlackBoardError < RuntimeError

  end

end
