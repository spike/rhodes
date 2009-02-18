require 'pathname'
  
class Hash
  def fetch_r(key)
    if self.has_key?(key) and not self[key].is_a?(Hash)
      return self[key]
    else
      self.each do |val|
	value = false 
	if val.is_a?(Array)
          val.each do |x|
            value = x.fetch_r(key) if x.is_a?(Hash)
  	    return value if value
  	  end
 	end
        value = val.fetch_r(key) if val.is_a?(Hash)
  	return value if value
      end
    end
    return false  
  end
end
  
class Jake


  def self.config(configfile)
    @@config = YAML::load(configfile)
    self.config_parse(@@config)
    @@config
  end

  def self.get_absolute(path)
    currentdir = pwd
    
    path = currentdir + "/" + path
  
    patharray = path.split(/\//)
  
    while idx = patharray.index("..") do
      if idx == 0
        raise "error getting absolute"
      end
     
      if patharray[idx-1] != ".."
        patharray.delete_at(idx)
        patharray.delete_at(idx-1)
      end
    end
    return patharray.join("/")  
  end	
  
  def self.config_parse(conf)
    if conf.is_a?(Array)
      conf.collect! do |x|
        if x.is_a?(Hash) or x.is_a?(Array)
          config_parse(x)
  	x
        else
  	if x =~ /%(.*?)%/
  	  x.gsub!(/%.*?%/, @@config.fetch_r($1).to_s)
          end
  	x
        end
      end
    elsif conf.is_a?(Hash)
      conf = conf.collect do |k,x|
  	    
        if x.is_a?(Hash) or x.is_a?(Array)
          config_parse(x)
  	x
        else 
  	if x.to_s =~ /%(.*?)%/
  	  x.gsub!(/%.*?%/, @@config.fetch_r($1).to_s)
          end
  	x
        end
      end
    end
  end
  
  def self.run(command, args, wd=nil,system = false)
    argstr = " "
    currentdir = ""
  
    args.each do |x|
      x = x.to_s
  #    x.gsub!(/"/,"\\\"")
      argstr +=  x + " "
      #argstr += "\"" + x + "\" "
    end
  
    if not wd.nil?
      currentdir = pwd()
      chdir wd  
    end
  puts "PWD:" + pwd
  puts "CMD:" + command
  puts "ARGS:" + argstr
    
    command = command + " " + argstr
    #retval =  `#{command} #{argstr}`
    #retval = %x[#{command}]
    if system
      system(command)
      retval = ""
    else
      bb = IO.popen(command)
      b = bb.readlines
      retval = b.join
    end
    if not wd.nil?
      chdir currentdir
    end
  
    return retval
  
  end
  
  def self.unjar(src,targetdir)
    cmd =  @@config["env"]["paths"][@@config["env"]["bbver"]]["java"] + "/jar.exe"
    p = Pathname.new(src)
    src = p.realpath
    currentdir = pwd()
    src = src.to_s.gsub(/"/,"")
  
    args = Array.new
  
    args << "xf"
    args << '"' + src.to_s + '"'
  
    chdir targetdir
    puts run(cmd,args)
    chdir currentdir
  end
  def self.jarfilelist(target)
    cmd = @@config["env"]["paths"][@@config["env"]["bbver"]]["java"] + "/jar.exe"
    target.gsub!(/"/,"")

    args = []
    args << "tf"
    args << '"' + target +'"'

    filelist = []
    run(cmd,args).each { |file| filelist << file if not file =~ /\/$/ }

    filelist
  end

  def self.jar(target,manifest,files,isfolder=false)
    cmd =  @@config["env"]["paths"][@@config["env"]["bbver"]]["java"] + "/jar.exe"
    target.gsub!(/"/,"")
    
    args = []
    args << "cfm"
    args << '"' + target +'"'
    args << manifest
    if isfolder
      args << "-C"
      args << files
      args << "."
    else
      args << files
    end
  
    puts run(cmd,args)
  
  
  end
  
  def self.rapc(output,destdir,imports,files,title=nil,vendor=nil,version=nil,icon=nil,library=true,cldc=false,quiet=true, nowarn=true)
    #cmd = @@config["env"]["paths"][@@config["env"]["bbver"]]["java"] + "/java.exe"
#   cmd = "java.exe"
    
    jdehome = @@config["env"]["paths"][@@config["env"]["bbver"]]["jde"]
    javabin = @@config["env"]["paths"][@@config["env"]["bbver"]]["java"]
    cmd = jdehome + "/bin/rapc.exe"
    
    currentdir = pwd()
  
  
    chdir destdir
  
    if output and title and version and vendor
      f = File.new(output + ".rapc", "w")
      f.write "MicroEdition-Profile: MIDP-2.0\n"
      f.write "MicroEdition-Configuration: CLDC-1.1\n"
      f.write "MIDlet-Name: " + output + "\n"
      f.write "MIDlet-Version: " + version + "\n"
      f.write "MIDlet-Vendor: " + vendor + "\n"
      f.write "MIDlet-Jar-URL: " + output + ".jar\n"
      f.write "MIDlet-Jar-Size: 0\n"
      f.write "RIM-Library-Flags: 2\n" if library

      if cldc and icon
        f.write "MIDlet-1: " + title + "," + icon + ",\n"
        f.write "RIM-MIDLET-Flags-1: 0\n"
      end

      f.close
    end
  
  
    args = []
    #args << "-classpath"
  #  args << "-jar"
    #args << '"' + jdehome + "/bin/rapc.jar\""
    #args << "net.rim.tools.compiler.Compiler"
    
    args << "\"-javacompiler=" + javabin + "/javac.exe\""
    args << "-quiet" if quiet
    args << "-nowarn" if nowarn
    args << '"import=' + imports + '"'
    args << 'codename=' + output
    args << 'library=' + output if library
    args << output + '.rapc'
    args << files
  
    cmd.gsub!(/\//,"\\")
    puts run( '"' + cmd + '"',args)
    chdir currentdir
  
  end
  
  def self.ant(dir,target)
  
    srcdir = @@config["build"]["srcdir"]
    rubypath = @@config["build"]["rubypath"]
    excludelib = @@config["build"]["excludelib"]
    compileERB = @@config["build"]["compileERB"]
    
  
    args = []
    args << "-buildfile"
    args << dir + "/build.xml"
    args << '"-Dsrc.dir=' + get_absolute(srcdir) + '"'
    args << '"-Druby.path=' + get_absolute(rubypath) + '"'
    args << '"-Dexclude.lib=' + excludelib + '"'
    args << '"-DcompileERB.path=' + get_absolute(compileERB) + '"'
    args << '"-Dsrclib.dir=' + get_absolute(srcdir) + '"'
  
  
    args << target
    #puts args.to_s
    puts run("ant.bat",args,dir)
  end
end
  
