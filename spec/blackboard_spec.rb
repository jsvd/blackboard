require 'spec'
require 'lib/blackboard'

class TestObject

  def initialize
    @timestamp = Time.now
  end

  attr_accessor :color
  attr_reader :timestamp
end

describe Pulso::Folder do

  it "should be created with a name, servers and ttl" do
    f = nil
    lambda { f = Pulso::Folder.new }.should raise_error ArgumentError
    lambda { f = Pulso::Folder.new :folder1, [], :servers => "127.0.0.1:11411" }.should raise_error ArgumentError
    lambda { f = Pulso::Folder.new :folder1, [], :ttl => 20 }.should raise_error ArgumentError
    lambda { f = Pulso::Folder.new :folder1, [], :servers => "127.0.0.1:11411", :ttl => 20 }.should_not raise_error ArgumentError
    f.name.should == :folder1
  end

end

describe Pulso::Data do

  it "should be initialized with a name and an object that responds to :timestamp" do
    lambda { Pulso::Data.new }.should raise_error
    lambda { Pulso::Data.new :name1, Object.new }.should raise_error Pulso::BlackBoardError
    obj = TestObject.new
    data = nil
    lambda { data = Pulso::Data.new :name1, obj }.should_not raise_error Pulso::BlackBoardError
    data.name.should == :name1
    data.data.should == obj
  end

  it "should have a timestamp" do
    Pulso::Data.new(:name1, TestObject.new).timestamp.should be_close Time.now,1
  end

end

describe Pulso::BlackBoard do

  before :all do
    `memcached -d -p 11411 -P /tmp/memcached-test.pid`
    @blackboard = Pulso::BlackBoard.new :ttl => 2
  end

  describe "(default)" do 

    it "should be active?" do
      @blackboard.should be_active
    end

    it "should not have folders" do
      @blackboard.should_not have_folders
    end

  end

  describe "(empty)" do

    it { @blackboard.should be_empty }

    it "should have folders after adding one" do
      @blackboard.add_folder :folder1, [:name1, :name2, :name3]
      @blackboard.should have_folders
      @blackboard.folders.keys.should include(:folder1)
    end

    # TODO improve by regexp matching
    it "should complain when retrieving from inexistant folder" do
      lambda { @blackboard.get :folder2, :name1 }.should raise_error Pulso::BlackBoardError
    end

    it "should return nil when retrieving known data key from folder" do
      @blackboard.get(:folder1, :name2).should be_nil
    end

    it "should complain when retrieving unknown data key from folder" do
      lambda { @blackboard.get(:folder1, :name5) }.should raise_error Pulso::BlackBoardError
    end

  end

  describe "(non-empty)" do
    
    before :all do
      @blackboard.add_folder :folder1, [:name1, :name2, :name3]
    end

    before :each do
      @obj = TestObject.new
      @obj.color = :green
      @blackboard.add :folder1, :name2, @obj
      @obj = TestObject.new
      @obj.color = :black
      @blackboard.add :folder1, :name3, @obj
      @obj = TestObject.new
      @obj.color = :blue
      @blackboard.add :folder1, :name1, @obj
    end

    it "should not be empty" do 
      @blackboard.should have_folders
      @blackboard.should_not be_empty
    end

    it "should complain when adding an existant folder" do
      lambda { @blackboard.add_folder :folder1, [:name3] }.should raise_error Pulso::BlackBoardError
    end

    it "should be able to retrieve object from a folder" do
      obj = @blackboard.get :folder1, :name1
      obj.color.should == :blue
    end

    it "should be empty after cleaning" do
      @blackboard.clean
      @blackboard.should be_empty
    end

    it "should not return nil when retrieving object whose time-to-live was not exceeded" do 
      `sleep 1`
      @blackboard.get(:folder1, :name1).should_not be_nil
    end

    it "should return nil when retrieving object whose time-to-live was exceeded" do 
      @blackboard.get(:folder1, :name1).should_not be_nil
      `sleep 2`
      @blackboard.get(:folder1, :name1).should be_nil
      @blackboard.add :folder1, :name1, @obj # already expired
      @blackboard.get(:folder1, :name1).should be_nil
    end

    it "should be possible to retrieve all data from a folder" do
      ret = @blackboard.get_folder :folder1
      ret[:name1].color.should == :blue
      ret[:name2].color.should == :green
      ret[:name3].color.should == :black
    end

    it "should timestamp the BlackBoard::Data object with current time when adding" do
      obj = TestObject.new
      obj.color = :blue
      @blackboard.add :folder1, :name1, obj
      @blackboard.timestamp(:folder1, :name1).should be_close Time.now, 0.2
    end

    it "should keep a Data object if new one is older" do
      obj1 = TestObject.new
      obj1.color = :blue
      `sleep 1`
      obj2 = TestObject.new
      obj2.color = :green
      @blackboard.add :folder1, :name2, obj2
      @blackboard.add :folder1, :name2, obj1
      obj = @blackboard.get :folder1, :name2
      obj.color.should == :green
    end

    it "should replace a Data object if new one is newer" do
      obj1 = TestObject.new
      obj1.color = :blue
      `sleep 1`
      obj2 = TestObject.new
      obj2.color = :green

      @blackboard.add :folder1, :name2, obj1
      obj = @blackboard.get :folder1, :name2
      obj.color.should == :blue

      @blackboard.add :folder1, :name2, obj2
      obj = @blackboard.get :folder1, :name2
      obj.color.should == :green
    end

    after :each do
      @blackboard.clean
    end
  end

  after :all do
    `killall memcached`
  end

end
