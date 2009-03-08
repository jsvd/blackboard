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
    instance_eval "def method_missing folder; raise BlackBoardError, \"Folder \#{folder} not found\"; end"
  end

  def has_folders?
    !@folders.empty?
  end

  def empty? 
    true
  end

  def clear
    @store.clear
  end

  def method_missing name, *args, &block

    raise BlackBoardError, "Folder #{name} already exists" if @folders.has_key?(name)
    instance_eval %Q{def #{name}; @folders[:#{name}]._update; @folders[:#{name}]; end}

    options = args[-1].is_a?(Hash) ? args.delete_at(-1) : {}
    options[:ttl] ||= @ttl
    options[:store] ||= @store

    @folders[name] = Folder.new name, args, options, &block

  end

  class Folder < Hash

    def initialize name, items, options, &block
      @name = name

      @folders = []
      @ttl = options[:ttl]
      @store = options[:store]

      raise ArgumentError, "Folder.new should not receive ttl bigger than #seconds in 30 days" if @ttl > 2592000

      create_children items 

      instance_eval(&block) unless block.nil?
      instance_eval "def method_missing folder; raise BlackBoardError, \"Folder \#{folder} not found\"; end"
    end

    def method_missing name, *args, &block

      raise BlackBoardError, "Folder #{name} already exists" if @folders.include?(name)
      instance_eval %Q{def #{name}; self[:#{name}]._update; self[:#{name}]; end}

      options = args[-1].is_a?(Hash) ? args.delete_at(-1) : {}
      options[:ttl] ||= @ttl
      options[:store] ||= @store

      self[name] = Folder.new "#{@name}.#{name}", args, options, &block

    end

    def _update
      @items.keys.each do |k|
        self[k] = get k
      end
      @folders.each {|f| ; self[f]._update }
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

