begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end
 
$:.unshift(File.join(File.dirname(__FILE__), '..'))
 
# Use the rubygem for local testing
require 'spec/stubs'
require 'rho/rho'
require 'rhom/rhom'

describe "rho initializer", :shared => true do

  attr_accessor :rhom, :rho

  before(:all) do
    FileUtils.mkdir_p('build')
  end

  after(:all) do
    FileUtils.rm_rf('build')
  end

  def array_print(arr)
    arr.each_with_index do |x,i|
      puts "arr[#{i}] = #{x.inspect}"
    end
  end
end

describe "rho db initializer", :shared => true do
  before(:each) do
    FileUtils.rm_rf('build/syncdbtest.sqlite')
    FileUtils.cp_r('spec/syncdbtest.sqlite','build/syncdbtest.sqlite')
    Object::const_set("SYNC_DB_FILE", "build/syncdbtest.sqlite") unless defined? SYNC_DB_FILE
    @rho = Rho::RHO.new(File.join(File.dirname(File.expand_path(__FILE__)), 'app_manifest.txt'))
    @rhom = Rhom::RhomObjectFactory.new
  end

  after(:each) do
    Rhom::RhomDbAdapter.close
    @rho = nil
    @rhom = nil
  end
end