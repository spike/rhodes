require File.join(File.dirname(__FILE__),'..','jake.rb')


task :config do
  $config = Jake.config(File.open('build.yml'))

  $basedir = pwd
  $bindir = File.join($basedir,'bin')
  $tmpdir = File.join($bindir,'tmp')
  $targetdir =  File.join($basedir,'target')
  $excludelib = ['**/rhom_db_adapter.rb','**/singleton.rb','**/TestServe.rb','**/rhoframework.rb','**/date.rb']
  $srcdir = File.join($bindir, '/RhoBundle')
  $compileERBbase = File.join(File.dirname(__FILE__),'..','compileERB')
  $appmanifest = File.join(File.dirname(__FILE__),'..','manifest','createAppManifest.rb')
  $res = File.join(File.dirname(__FILE__),'..','..','res')

  $prebuilt = File.join($res,'prebuilt')
  mkdir_p $bindir if not File.exists? $bindir
end


task :loadframework => :config do
  require 'rhodes-framework'
  puts $rhodeslib
end

namespace "bundle" do
  desc "create BB bundle"
  task :bb => :loadframework do
    jdehome = $config["env"]["paths"][$config["env"]["bbver"]]["jde"]

    rm_rf $srcdir
    mkdir_p $srcdir
    mkdir_p File.join($srcdir,'apps')

    compileERB = File.join($compileERBbase,'bb.rb')
    rubypath =  File.join($res,'RhoRuby.exe')
    xruby =  File.join($res,'xruby-0.3.3.jar')

    dest = $srcdir 
    chdir $rhodeslib
    Dir.glob("*").each { |f| 
      src = f
      cp_r src,dest
    }
    chdir dest
    Dir.glob("**/rhodes-framework.rb").each {|f| rm f}
    Dir.glob("**/erb.rb").each {|f| rm f}
    Dir.glob("**/find.rb").each {|f| rm f}
    $excludelib.each {|e| Dir.glob(e).each {|f| rm f}}

    chdir $basedir
#throw "ME"
    cp_r 'app',File.join($srcdir,'apps')
    cp_r 'public', File.join($srcdir,'apps')
    cp   'config.rb', File.join($srcdir,'apps')
    #cp   'index.erb', File.join($srcdir,'apps')
    #cp   'layout.erb', File.join($srcdir,'apps')
    #cp   'loading.html', File.join($srcdir,'apps')
    cp   $appmanifest, $srcdir
    puts `#{rubypath} -R#{$rhodeslib} #{$srcdir}/createAppManifest.rb` 
    rm   File.join($srcdir,'createAppManifest.rb')
    cp   compileERB, $srcdir
    puts `#{rubypath} -R#{$rhodeslib} #{$srcdir}/bb.rb` 

    chdir $bindir
    puts `java -jar #{xruby} -c RhoBundle`
    chdir $srcdir
    Dir.glob("**/*.rb") { |f| rm f }
    Dir.glob("**/*.erb") { |f| rm f }
    puts `jar uf ../RhoBundle.jar apps/*.*`
    chdir $basedir
    
    rm_rf $srcdir

    args = []
    args << "-classpath"
    args << '"' + jdehome + "/lib/net_rim_api.jar;" + File.join($prebuilt, "bb","RubyVM.jar") + '"'
    args << "-d"
    args << $bindir
    args << $bindir + "/RhoBundle.jar"
    puts Jake.run(jdehome + "/bin/preverify.exe",args)
    $stdout.flush

    rm_rf $tmpdir
    mkdir_p $tmpdir

    rm_rf $targetdir
    mkdir_p $targetdir

    Jake.unjar(File.join($prebuilt, "bb","RubyVM.jar"), $tmpdir) 
    Jake.unjar($bindir + "/RhoBundle.jar", $tmpdir) 
    Jake.unjar(File.join($prebuilt, "bb","rhodes.jar"), $tmpdir) 

    Jake.jar($bindir + "/rhodesApp.jar",'"' + File.join($prebuilt, "bb","manifest.mf") + '"',$tmpdir,true)
    Jake.rapc("rhodesApp", 
           $targetdir,
           jdehome + "/lib/net_rim_api.jar",
           '"' + $bindir + "/rhodesApp.jar" +'"',
           "rhodesApp",
           $config["env"]["vendor"],
           $config["env"]["version"],
           "resources/icon.png",
           false,
           true
      )
      $stdout.flush

    cp  File.join($prebuilt, "bb","rhodesApp.alx"), $targetdir
    if $config["env"]["bbsignpwd"] and $config["env"]["bbsignpwd"] != ""
      Rake::Task["run:autosign"].execute
    else
      Rake::Task["run:manualsign"].execute
    end

    rm_rf $targetdir + "/web"
    mkdir_p $targetdir + "/web" 

    #cp $targetdir + "/rhodesApp.jad", $targetdir + "/web"

    #Jake.unjar($targetdir + "/rhodesApp.cod", $targetdir + "/web")



      #cp "./rhodesApp.alx", config["build"]["targetdir"] if not FileUtils.uptodate?( config["build"]["targetdir"]+"/rhodesApp.alx", "./rhodesApp.alx")


    #cp $config["build"]["bindir"] + "/RhoBundle.jar", $config["build"]["rhobundledir"] + "/RhoBundle.jar"

  #  cp_r Dir.glob("**/*.rb"), dest
  end
end

namespace "run" do

  desc "Run Sim"
  task :sim do
    sim = $config["env"]["paths"][$config["env"]["bbver"]]["sim"].to_s
    jde = $config["env"]["paths"][$config["env"]["bbver"]]["jde"]
  
    command =  '"' + jde + "/simulator/fledge.exe\""
    args = [] 
    args << "/app=Jvm.dll"
    args << "/handheld=" + sim
    args << "/session=" + sim
    args << "/app-param=DisableRegistration"
    args << "/app-param=JvmAlxConfigFile:"+sim+".xml"
    args << "/data-port=0x4d44"
    args << "/data-port=0x4d4e"
    args << "/pin=0x2100000A"
    args << "\"/app-param=JvmDebugFile:"+ File.join($basedir,'applog.txt') +'"'

    Thread.new { Jake.run(command,args,jde + "/simulator",true) }
    $stdout.flush
  end

  desc "Run MDS"
  task :mds do
    mdshome =  $config["env"]["paths"][$config["env"]["bbver"]]["mds"]
    args = []
    args << "/c"
    args << "run.bat"

    Thread.new { Jake.run("cmd.exe",args, mdshome,true) }

  end

  desc "Builds everything, loads and starts sim"
  task :app  => ["bundle:bb", "run:mds", "run:sim"] do
    sim = $config["env"]["paths"][$config["env"]["bbver"]]["sim"].to_s
    jde = $config["env"]["paths"][$config["env"]["bbver"]]["jde"]
  
    puts "sleeping to allow simulator to get started"
    sleep 25

    command = '"' + jde + "/simulator/fledgecontroller.exe\""
    args = []
    args << "/session="+sim
    args << "\"/execute=LoadCod(" + File.join($targetdir,"rhodesApp.cod") + ")\""

    Jake.run(command,args, jde + "/simulator")
 #   $stdout.flush
 #   sleep 15

 #   args = []
 #   args << "/session="+sim
 #   args << "/execute=Exit(true)"
 #   Jake.run(command,args, jde + "/simulator")
 #   $stdout.flush
 #   sleep 5

 #   Rake::Task["run:sim"].execute
    $stdout.flush
  end

  desc "Sign cod files automatically"
  task :autosign do
    java = $config["env"]["paths"][$config["env"]["bbver"]]["java"] + "/java.exe"
    jde = $config["env"]["paths"][$config["env"]["bbver"]]["jde"] 
  
    args = []
    args << "-jar"
    args << '"' + jde + "/bin/SignatureTool.jar\""
    args << "-c"
    args << "-a"
    args << "-p"
    args << '"' + config["build"]["bbsignpwd"] +'"'
    args << "-r"
    args << $targetdir

    puts Jake.run(java,args)
    $stdout.flush

  end

  desc "Sign cod files manually"
  task :manualsign do
    java = $config["env"]["paths"][$config["env"]["bbver"]]["java"] + "/java.exe"
    jde = $config["env"]["paths"][$config["env"]["bbver"]]["jde"] 
    
    args = []
    args << "-jar"
    args << '"' + jde + "/bin/SignatureTool.jar\""
    args << "-r"
    args << $targetdir
  
    puts Jake.run(java,args)
    $stdout.flush
  
  end

end
