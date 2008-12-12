module Pulso

  class Folder

    attr_reader :name, :ttl, :keys

    def initialize name, keys, args = {}
      @name = name

      @ttl = args[:ttl]
      raise ArgumentError, "Pulso::Folder.new should receive name, keys, servers and ttl" if @ttl.nil? || args[:servers].nil?

      @keys = {}
      keys.each {|key| @keys[key] = Time.at 0 }
      @cache = MemCache.new args[:servers], :namespace => name
    end

    def add name, object
      obj_ttl = (@ttl - (Time.now - object.timestamp)).round
      return unless obj_ttl > 0

      @keys[name] = object.timestamp
      @cache.set name, Pulso::Data.new(name, object), obj_ttl
    end
    
    def get obj_name
      raise BlackBoardError, "Key #{obj_name} doesn't exist in folder #{@name}." unless @keys.has_key?(obj_name)
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
      @ttl = opts[:ttl] || 60
      @servers = opts[:servers]
      @servers ||= "127.0.0.1:11411"
      @cache = MemCache.new(@servers)
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

    def add_folder name, keys, ttl = @ttl
      raise BlackBoardError, "Folder #{name} already exists" if @folders.has_key?(name)
      folder = Pulso::Folder.new name, keys, :servers => @servers, :ttl => ttl
      @folders[name] = folder
    end

    def add folder, tag, object
      return if object.timestamp < timestamp(folder, tag)
      @folders[folder].add tag, object
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
      @cache.flush_all
    end

  end

  class BlackBoardError < RuntimeError

  end

end
