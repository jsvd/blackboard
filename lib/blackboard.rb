# vim: expandtab : tabstop=2 : shiftwidth=2 : softtabstop=2
require 'moneta'
require 'moneta/memcache'

class BlackBoard

  @store = nil

  attr_reader :folders

  def initialize opts = {}, &block
    @folders = {}
    @ttl = opts[:ttl] || 60
    raise ArgumentError, "BlackBoard.new should not receive ttl bigger than #seconds in 30 days" if @ttl > 2592000
    @store = opts[:store] || Moneta::Memcache.new(:server => "127.0.0.1:11411")
    instance_eval(&block) unless block.nil?
  end

  def has_folders?
    !@folders.empty?
  end

  def empty? 
    true
  end

  def folder name, keys, args = {}, &block
    raise BlackBoardError, "Folder #{name} already exists" if @folders.has_key?(name)
    ttl = args[:ttl]
    ttl ||= @ttl
    instance_eval %Q{def #{name}; @folders[:#{name}]._update; @folders[:#{name}]; end}
    @folders[name] = Folder.new name, keys, :cache => @store, :ttl => ttl, &block
  end

  def clear
    @store.clear
  end

  def method_missing folder
    raise BlackBoardError, "Folder #{folder} not found"
  end

  class Folder < Hash

    def initialize name, children, args = {}, &block
      @name = name

      @folders = []
      @ttl = args[:ttl]
      @store = args[:cache]

      raise ArgumentError, "Folder.new should receive name, keys, cache and ttl" if @ttl.nil? || args[:cache].nil?
      raise ArgumentError, "Folder.new should not receive ttl bigger than #seconds in 30 days" if @ttl > 2592000

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
      @folders << name
      self[name] = Folder.new "#{@name}.#{name}", keys, :cache => @store, :ttl => ttl, &block
      instance_eval %Q{def #{name}; self[:#{name}]._update ;self[:#{name}]; end}

    end

    def create_children children
      @items = {}
      children.each do |child| 
        self[child] = nil
        instance_eval %Q{
          def #{child}=(object)
            add :#{child}, object
          end

          def #{child}
            self[:#{child}] = get :#{child}
          end
        }
        @items[child] = Time.at 0 
      end
    end

    def add name, object
      obj_ttl = (@ttl - (Time.now - object.timestamp)).round
      return unless obj_ttl > 0
      return if object.timestamp < @items[name]

      @items[name] = object.timestamp
      obj = Data.new(name, object)
      @store.store "#{@name}.#{name}", obj, :expires_in => obj_ttl
    end

    def get obj_name
      raise BlackBoardError, "Key #{obj_name} doesn't exist in folder #{@name}." unless @items.has_key?(obj_name)
      ret = @store["#{@name}.#{obj_name}"]
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
end

class BlackBoardError < RuntimeError
end

