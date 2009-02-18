
basedir = pwd
bindir = File.join(basedir,'/bin')
excludelib = ['**/rhom_db_adapter.rb','**/singleton.rb','**/TestServe.rb','**/rhoframework.rb','**/date.rb']
srcdir = File.join(bindir, '/RhoBundle')
compileERBbase = File.join(File.dirname(__FILE__),'..','compileERB')
appmanifest = File.join(File.dirname(__FILE__),'..','manifest','createAppManifest.rb')
res = File.join(File.dirname(__FILE__),'..','..','res')

mkdir_p bindir if not File.exists? bindir

task :loadframework do
  require 'rhodes-framework'
  puts $rhodeslib
end

namespace "bundle" do
  desc "create BB bundle"
  task :bb => :loadframework do
    rm_rf srcdir
    mkdir_p srcdir
    mkdir_p File.join(srcdir,'apps')

    compileERB = File.join(compileERBbase,'bb.rb')
    rubypath =  File.join(res,'RhoRuby.exe')
    xruby =  File.join(res,'xruby-0.3.3.jar')

    src = $rhodeslib
    dest = srcdir 
    cp_r src,dest
    chdir dest
    Dir.glob("**/erb.rb").each {|f| rm f}
    Dir.glob("**/find.rb").each {|f| rm f}
    excludelib.each {|e| Dir.glob(e).each {|f| rm f}}

    chdir basedir

    cp_r 'app',File.join(srcdir,'apps')
    cp_r 'public', File.join(srcdir,'apps')
    cp   'config.rb', File.join(srcdir,'apps')
    cp   appmanifest, srcdir
    puts `#{rubypath} -R#{$rhodeslib} #{srcdir}/createAppManifest.rb` 
    rm   File.join(srcdir,'createAppManifest.rb')
    cp   compileERB, srcdir
    puts `#{rubypath} -R#{$rhodeslib} #{srcdir}/bb.rb` 

    chdir bindir
    puts `java -jar #{xruby} -c RhoBundle`
    chdir srcdir
    Dir.glob("**/*.rb") { |f| rm f }
    Dir.glob("**/*.erb") { |f| rm f }
    puts `jar uf ../RhoBundle.jar apps/*.*`
    chdir basedir

  #  cp_r Dir.glob("**/*.rb"), dest
  end
end


desc "blah!"
task :blah => :loadframework do
	puts __FILE__
end
