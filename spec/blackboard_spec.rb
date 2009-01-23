require 'spec'
require 'lib/blackboard'

class TestObject

  def initialize
    @timestamp = Time.now
  end

  attr_accessor :color
  attr_reader :timestamp
end

describe BlackBoard::Folder do

  before :each do
    @cache = MemCache.new("127.0.0.1:11411", :namespace => 'blackboard')
  end

  it "should be created with a name, servers and ttl" do
    f = nil
    lambda { f = BlackBoard::Folder.new }.should raise_error ArgumentError
    lambda { f = BlackBoard::Folder.new :folder1, [], :cache => @cache }.should raise_error ArgumentError
    lambda { f = BlackBoard::Folder.new :folder1, [], :ttl => 20 }.should raise_error ArgumentError
    lambda { f = BlackBoard::Folder.new :folder1, [], :cache => @cache, :ttl => 20 }.should_not raise_error ArgumentError
    f.instance_eval("@name").should == :folder1
  end

  it "should complain if ttl is bigger than seconds in 30 days" do
    lambda { BlackBoard::Folder.new :folder1, [], :cache => @cache, :ttl => 30*24*3600+1 }.should raise_error ArgumentError
    lambda { BlackBoard::Folder.new :folder1, [], :cache => @cache, :ttl => 30*24*3600 }.should_not raise_error ArgumentError
  end

  it "should not complain when creating subfolders" do
    lambda { 
      BlackBoard::Folder.new :folder1, [:name1, :name2], :cache => @cache, :ttl => 30*24*3600 do
        folder :folder2, [:name4, :name5], :ttl => 30*24*3600
      end
    }.should_not raise_error ArgumentError
  end

  it "should return a kind of Hash" do
    f = BlackBoard::Folder.new :folder1, [:name1], :cache => @cache, :ttl => 20
    f.should be_a_kind_of Hash
    f.should == { :name1 => nil }
  end

  it "should respond to folder name method" do
    `memcached -d -p 11411 -P /tmp/memcached-test.pid`
    k = BlackBoard::Folder.new :folder1, [:name1, :name2], :cache => @cache, :ttl => 30*24*3600 do
      folder :folder2, [:name1]
    end
    lambda { k.folder2 }.should_not raise_error
    k.folder2.should == { :name1 => nil } 
    `killall memcached`
  end

end

describe BlackBoard::Data do

  it "should be initialized with a name and an object that responds to :timestamp" do
    lambda { BlackBoard::Data.new }.should raise_error
    lambda { BlackBoard::Data.new :name1, Object.new }.should raise_error BlackBoardError
    obj = TestObject.new
    data = nil
    lambda { data = BlackBoard::Data.new :name1, obj }.should_not raise_error BlackBoardError
    data.name.should == :name1
    data.data.should == obj
  end

  it "should have a timestamp" do
    BlackBoard::Data.new(:name1, TestObject.new).timestamp.should be_close Time.now,1
  end

end

describe BlackBoard do

  before :all do
    `memcached -d -p 11411 -P /tmp/memcached-test.pid`
    @blackboard = BlackBoard.new :ttl => 2 do
      folder :folder1, [:name1, :name2]
    end
  end

  describe "(default)" do 

    it "should be active?" do
      @blackboard.should be_active
    end

    it "should have folders" do
      @blackboard.should have_folders
    end

    it "should complain if ttl is bigger than seconds in 30 days" do
      lambda { BlackBoard.new :ttl => 30*24*3600+1 }.should raise_error ArgumentError
      lambda { BlackBoard.new :ttl => 30*24*3600 }.should_not raise_error ArgumentError
    end

  end

  describe "(empty)" do

    it { @blackboard.should be_empty }

    it "should have folders after adding one" do
      bb = BlackBoard.new do
        folder :folder1, [:name1, :name2]
      end
      bb.should have_folders
      bb.folders.keys.should include(:folder1)
    end

    # TODO improve by regexp matching
    it "should complain when retrieving from inexistant folder" do
      lambda { @blackboard.folder2.name1 }.should raise_error BlackBoardError
    end

    it "should return nil when retrieving known data key from folder" do
      @blackboard.folder1.name2.should be_nil
    end

    it "should complain when retrieving unknown data key from folder" do
      lambda { @blackboard.folder1.name5 }.should raise_error BlackBoardError
    end

  end

  describe "(non-empty)" do
    
    before :all do
      @blackboard = BlackBoard.new :ttl => 2 do
        folder :folder1, [:name1, :name2, :name3]
        folder :folder2, [:name4, :name5, :name6]
      end
      @blackboard.folders.keys.should include(:folder1)
    end

    before :each do
      @obj = TestObject.new
      @obj.color = :green
      @blackboard.folder1.name2 = @obj
      @obj = TestObject.new
      @obj.color = :black
      @blackboard.folder1.name3 = @obj
      @obj = TestObject.new
      @obj.color = :blue
      @blackboard.folder1.name1 = @obj
    end

    it "should not be empty" do 
      @blackboard.should have_folders
      obj = TestObject.new
      obj.color = :green
      @blackboard.folder1.name2 = obj
      @blackboard.should_not be_empty
    end

    it "should be able to retrieve object from a folder" do
      obj = @blackboard.folder1.name1
      obj.color.should == :blue
    end

    it "should be empty after cleaning" do
      @blackboard.clean
      @blackboard.should be_empty
    end

    it "should not return nil when retrieving object whose time-to-live was not exceeded" do 
      `sleep 1`
      @blackboard.folder1.name1.should_not be_nil
    end

    it "should return nil when retrieving object whose time-to-live was exceeded" do 
      @blackboard.folder1.name1.should_not be_nil
      `sleep 2`
      @blackboard.folder1.name1.should be_nil
      @blackboard.folder1.name1 = @obj # already expired
      @blackboard.folder1.name1.should be_nil
    end

    it "should be possible to retrieve all data from a folder" do
      ret = @blackboard.folder1
      ret.name1.color.should == :blue
      ret.name2.color.should == :green
      ret.name3.color.should == :black
    end

    it "should timestamp the BlackBoard::Data object with current time when adding" do
      obj = TestObject.new
      obj.color = :blue
      @blackboard.folder1.name1 = obj
      @blackboard.folder1.name1.timestamp.should be_close Time.now, 0.2
    end

    it "should keep a Data object if new one is older" do
      obj1 = TestObject.new
      obj1.color = :blue
      `sleep 1`
      obj2 = TestObject.new
      obj2.color = :green
      @blackboard.folder2.name5 = obj2
      @blackboard.folder2.name5 = obj1
      obj = @blackboard.folder2.name5
      obj.color.should == :green
    end

    it "should replace a Data object if new one is newer" do
      obj1 = TestObject.new
      obj1.color = :blue
      `sleep 1`
      obj2 = TestObject.new
      obj2.color = :green

      @blackboard.folder1.name2 = obj1
      obj = @blackboard.folder1.name2
      obj.color.should == :blue

      @blackboard.folder1.name2 = obj2
      obj = @blackboard.folder1.name2
      obj.color.should == :green
    end

    after :each do
      @blackboard.clean
    end
  end

  describe "(with subfolders)" do

    it "should allow subfolders" do

      lambda { 
        @blackboard = BlackBoard.new :ttl => 2 do
          folder :folder1, [:name1, :name2, :name3] do
            folder :folder2, [:name4, :name5]
          end
        end
      }.should_not raise_error

      @blackboard.folder1.should == { :name1 => nil, :name2 => nil, :name3 => nil, :folder2 => { :name4 => nil, :name5 => nil } }

    end

    it "should be possible to write to a subfolder" do

      @blackboard = BlackBoard.new :ttl => 2 do
        folder :folder1, [:name1, :name2, :name3] do
          folder :folder2, [:name4, :name5]
        end
      end

      obj = TestObject.new 
      obj.color = :green

      lambda { @blackboard.folder1.folder2.name5 = obj }.should_not raise_error

      ret = @blackboard.folder1.folder2.name5
      ret.color.should == :green

      ret = @blackboard.folder1.folder2
      ret[:name4].should be_nil
      ret[:name5].color.should == :green

      lambda { @blackboard.folder1.folder2.name5 = obj }.should_not raise_error

    end

    it "should allow different ttl for subfolders" do
      @blackboard = BlackBoard.new :ttl => 2 do
        folder :folder1, [:name1], :ttl => 1
        folder :folder2, [:name2], :ttl => 2
      end
      obj = TestObject.new 
      obj.color = :green
      @blackboard.folder1.name1 = obj
      @blackboard.folder2.name2 = obj
      @blackboard.folder1.name1.should_not be_nil
      @blackboard.folder2.name2.should_not be_nil
      `sleep 1`
      @blackboard.folder1.name1.should be_nil
      @blackboard.folder2.name2.should_not be_nil
      `sleep 1`
      @blackboard.folder1.name1.should be_nil
      @blackboard.folder2.name2.should be_nil
    end

    it "should allow different ttl between folder and subfolder" do
      @blackboard = BlackBoard.new :ttl => 2 do
        folder :folder1, [:name1], :ttl => 1 do
          folder :folder2, [:name2], :ttl => 2
        end
      end
      obj = TestObject.new 
      obj.color = :green
      @blackboard.folder1.name1 = obj
      @blackboard.folder1.folder2.name2 = obj

      @blackboard.folder1.name1.should_not be_nil
      @blackboard.folder1.folder2.name2.should_not be_nil
      `sleep 1`
      @blackboard.folder1.name1.should be_nil
      @blackboard.folder1.folder2.name2.should_not be_nil
      `sleep 1`
      @blackboard.folder1.name1.should be_nil
      @blackboard.folder1.folder2.name2.should be_nil
    end

    it "should propagate tll to subfolders " do
      @blackboard = BlackBoard.new :ttl => 2 do
        folder :folder1, [:name1], :ttl => 1 do
          folder :folder2, [:name2]
        end
      end
      obj = TestObject.new 
      obj.color = :green
      @blackboard.folder1.name1 = obj
      @blackboard.folder1.folder2.name2 = obj

      @blackboard.folder1.name1.should_not be_nil
      @blackboard.folder1.folder2.name2.should_not be_nil
      `sleep 1`
      @blackboard.folder1.name1.should be_nil
      @blackboard.folder1.folder2.name2.should be_nil
      `sleep 1`
      @blackboard.folder1.name1.should be_nil
      @blackboard.folder1.folder2.name2.should be_nil
    end

    it "should support writing to two elements with same name on different folders" do
      @blackboard = BlackBoard.new :ttl => 10 do
        folder :folder1, [:name1]
        folder :folder2, [:name1]
      end
      obj = TestObject.new 
      obj.color = :green
      @blackboard.folder1.name1 = obj
      obj = TestObject.new 
      obj.color = :blue
      @blackboard.folder2.name1 = obj

      @blackboard.folder1.name1.color.should == :green
      @blackboard.folder2.name1.color.should == :blue
    end

    it "should not complain when creating sub sub folders" do
      lambda { @blackboard = BlackBoard.new :ttl => 10 do
        folder :folder1, [:name1] do
          folder :folder1, [:name1] do
            folder :folder1, [:name1] do
              folder :folder1, [:name1] do
                folder :folder1, [:name1] do
                  folder :folder1, [:name1]
                end
              end
            end
          end
        end
      end }.should_not raise_error
      obj = TestObject.new 
      obj.color = :green
      @blackboard.folder1.folder1.folder1.folder1.folder1.folder1.name1 = obj
      @blackboard.folder1.folder1.folder1.folder1.folder1.folder1.name1.color.should == :green
    end

  end

  after :all do
    `killall memcached`
  end

end
