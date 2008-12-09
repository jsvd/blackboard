module Pulso

  class Folder

    attr_reader :name, :timestamp, :keys

    def initialize name, keys, servers = "127.0.0.1:11411"
      @name = name
      @keys = {}
      keys.each do |key|
        @keys[name] = nil # timestamp
      end

      @cache = MemCache.new servers, :namespace => name
      @timestamp = Time.at 0
    end

    def add obj, ttl
      @keys[obj.name] = obj.timestamp
      @cache.add obj.name, obj, ttl
    end
    
    def get obj_name
      ret = @cache[obj_name]
      return if ret.nil?
      ret.data
    end

    def get_all
      @cache.get_multi(*@keys.keys)
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

    attr_reader  :folders

    def initialize opts = {}
      @folders = {}
      @ttl = opts[:ttl] || 2
      @servers = opts[:servers]
      @servers ||= "127.0.0.1:11411"
    end

    def active?
     true #FIXME
    end

    def has_folders?
      !@folders.empty?
    end

    def empty? 
      MemCache.new(@servers).stats.inject(0) {|sum, server| sum + server.last["curr_items"]} == 0
    end

    def add_folder name, keys
      folder = Pulso::Folder.new name, keys, @servers
      @folders[name] = folder
    end

    def add folder, tag, object
      obj_ttl = (@ttl - (Time.now - object.timestamp)).round
      return unless obj_ttl > 0
      @folders[folder].add Pulso::Data.new(tag, object), obj_ttl
    end

    def get folder, obj_name
      raise BlackBoardError, "Folder #{folder} not found" unless @folders.has_key?(folder)
      @folders[folder].get obj_name
    end

    def get_folder folder
      ret = {}
      @folders[folder].get_all.each do |k,v|
        ret.store k, v.data
      end
      ret
    end

    def timestamp folder, obj_name
      @folders[folder].keys[obj_name]
    end

    def clean
      MemCache.new(@servers).flush_all
    end

  end

  class BlackBoardError < RuntimeError

  end

end
