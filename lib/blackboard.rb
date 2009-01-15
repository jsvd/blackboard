# vim: expandtab : tabstop=2 : shiftwidth=2 : softtabstop=2

module Pulso

  class Folder < Hash

    attr_reader :name, :ttl

    def initialize name, children, args = {}, &block
      @name = name

      @items = {}
      @folders = []
      @ttl = args[:ttl]
      @cache = args[:cache]

      raise ArgumentError, "Pulso::Folder.new should receive name, keys, cache and ttl" if @ttl.nil? || args[:cache].nil?
      raise ArgumentError, "Pulso::Folder.new should not receive ttl bigger than #seconds in 30 days" if @ttl > 2592000

      create_children children
      
      instance_eval(&block) unless block.nil?

    end

    def method_missing folder
      raise BlackBoardError, "Folder #{folder} not found"
    end

    def _update
      @items.keys.each do |k|
        self[k] = get k
      end
      @folders.each {|f| self[f]._update }
    end

    private
    def folder name, keys, args = {}, &block
      raise BlackBoardError, "Folder #{name} already exists" if self.has_key?(name)
      ttl = args[:ttl]
      ttl ||= @ttl
      folder = Pulso::Folder.new "#{@name}.#{name}", keys, :cache => @cache, :ttl => ttl, &block
      @folders << name
      self[name] = folder
      instance_eval %Q{def #{name}; self[:#{name}]._update ;self[:#{name}]; end}
      instance_eval(&block) unless block.nil?
    end

    def create_children children
      children.each do |child| 
        self[child] = nil
        instance_eval %Q{
        def #{child}=(object); add :#{child}, object; end
        def #{child}; self[:#{child}] = get :#{child}; end}
        @items[child] = Time.at 0 
      end
    end

    def add name, object
      obj_ttl = (@ttl - (Time.now - object.timestamp)).round
      return unless obj_ttl > 0
      return if object.timestamp < @items[name]
      #puts "adding #{name} that has color #{object.color}"

      @items[name] = object.timestamp
      obj = Pulso::Data.new(name, object)
      @cache.set "#{@name}.#{name}", obj, obj_ttl
    end

    def get obj_name
      raise BlackBoardError, "Key #{obj_name} doesn't exist in folder #{@name}." unless @items.has_key?(obj_name)
      ret = @cache["#{@name}.#{obj_name}"]
      return if ret.nil?
      ret.data
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

    attr_reader :folders

    def initialize opts = {}, &block
      @folders = {}
      @ttl = opts[:ttl] || 60
      raise ArgumentError, "Pulso::BlackBoard.new should not receive ttl bigger than #seconds in 30 days" if @ttl > 2592000
      @servers = opts[:servers]
      @servers ||= "127.0.0.1:11411"
      @cache = MemCache.new(@servers, :namespace => 'blackboard')
      instance_eval(&block) unless block.nil?
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

    def folder name, keys, args = {}, &block
      raise BlackBoardError, "Folder #{name} already exists" if @folders.has_key?(name)
      ttl = args[:ttl]
      ttl ||= @ttl
      folder = Pulso::Folder.new name, keys, :cache => @cache, :ttl => ttl, &block
      @folders[name] = folder
      instance_eval %Q{def #{name}; @folders[:#{name}]._update; @folders[:#{name}]; end}
    end

    def clean
      @cache.flush_all
    end

    def method_missing folder
      raise BlackBoardError, "Folder #{folder} not found"
    end

  end

  class BlackBoardError < RuntimeError

  end

end
