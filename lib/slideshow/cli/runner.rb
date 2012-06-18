module Slideshow

class Runner

  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    @opts    = Opts.new
    @config  = Config.new( @logger, @opts )
    @headers = Headers.new( @config )
  end

  attr_reader :logger, :opts, :config, :headers


  def load_plugins
    patterns = []
    patterns << "#{config.config_dir}/lib/**/*.rb"
    patterns << 'lib/**/*.rb' unless Slideshow.root == File.expand_path( '.' )  # don't include lib if we are in repo (don't include slideshow/lib)
  
    patterns.each do |pattern|
      pattern.gsub!( '\\', '/')  # normalize path; make sure all path use / only
      Dir.glob( pattern ) do |plugin|
        begin
          puts "Loading plugins in '#{plugin}'..."
          require( plugin )
        rescue Exception => e
          puts "** error: failed loading plugins in '#{plugin}': #{e}"
        end
      end
    end
  end  # method load_plugins


  def find_file_with_known_extension( fn )
    dirname  = File.dirname( fn )
    basename = File.basename( fn, '.*' )
    extname  = File.extname( fn )
    logger.debug "dirname=#{dirname}, basename=#{basename}, extname=#{extname}"

    config.known_extnames.each do |e|
      newname = File.join( dirname, "#{basename}#{e}" )
      logger.debug "File.exists? #{newname}"
      return newname if File.exists?( newname )
    end  # each extension (e)
      
    nil   # not found; return nil
  end


  def find_files( file_or_dir_or_pattern )
    filtered_files = []
 
    ## for now process/assume only single file
    
    ## (check for missing extension)
    if File.exists?( file_or_dir_or_pattern )
      file = file_or_dir_or_pattern
      logger.debug "  adding file '#{file}'..."
      filtered_files << file
    else  # check for existing file w/ missing extension
      file = find_file_with_known_extension( file_or_dir_or_pattern )
      if file.nil?
        puts "  skipping missing file '#{file_or_dir_or_pattern}{#{config.known_extnames.join(',')}}'..."
      else
        logger.debug "  adding file '#{file}'..."
        filtered_files << file
      end
    end
    
    filtered_files 
  end # method find_files



def run( args )

  config.load

  opt=OptionParser.new do |cmd|
    
    cmd.banner = "Usage: slideshow [options] name"
        
    cmd.on( '-o', '--output PATH', "Output Path (default is #{opts.output_path})" ) { |path| opts.output_path = path }
    
    cmd.on( "-t", "--template MANIFEST", "Template Manifest (default is #{opts.manifest})" ) do |t|
      # todo: do some checks on passed in template argument
      opts.manifest = t
    end


  #  cmd.on( '--header NUM', 'Header Level (default is 1)' ) do |n|
  #    opts.header_level = n.to_i
  #  end

    cmd.on( '--h1', 'Set Header Level to 1 (default)' ) { opts.header_level = 1 }
    cmd.on( '--h2', 'Set Header Level to 2' ) { opts.header_level = 2 }


    # ?? opts.on( "-s", "--style STYLE", "Select Stylesheet" ) { |s| $options[:style]=s }
        
    # ?? cmd.on( '-i', '--include PATH', 'Load Path' ) { |s| opts.put( 'include', s ) }

    cmd.on( '-f', '--fetch URI', 'Fetch Templates' ) do |uri|
      opts.fetch_uri = uri
    end

    cmd.on( '-l', '--list', 'List Installed Templates' ) { opts.list = true }

    cmd.on( '-c', '--config PATH', "Configuration Path (default is #{opts.config_path})" ) do |path|
      opts.config_path = path
    end

    cmd.on( '-g', '--generate',  'Generate Slide Show Templates (using built-in S6 Pack)' ) { opts.generate = true }
    
    ## fix:/todo: add generator for quickstart
    cmd.on( '-q', '--quick', 'Generate Quickstart Slide Show Sample') { opts.quick = true }


    cmd.on( '-v', '--version', "Show version" ) do
      puts Slideshow.generator
      exit
    end

    cmd.on( "--verbose", "Show debug trace" )  do
       logger.datetime_format = "%H:%H:%S"
       logger.level = Logger::DEBUG
    end
    
 
    cmd.on_tail( "-h", "--help", "Show this message" ) do
         puts <<EOS
         
Slide Show (S9) is a free web alternative to PowerPoint or KeyNote in Ruby

#{cmd.help}

Examples:
  slideshow microformats
  slideshow microformats.text            # Process slides using Markdown (#{config.known_markdown_extnames.join(', ')})
  slideshow microformats.textile         # Process slides using Textile (#{config.known_textile_extnames.join(', ')})
  slideshow microformats.rst             # Process slides using reStructuredText (#{config.known_rest_extnames.join(', ')})
  slideshow -o slides microformats       # Output slideshow to slides folder

More examles:
  slideshow -q                           # Generate quickstart slide show sample
  slideshow -g                           # Generate slide show templates using built-in S6 pack

  slideshow -l                           # List installed slide show templates
  slideshow -f s5blank                   # Fetch (install) S5 blank starter template from internet
  slideshow -t s5blank microformats      # Use your own slide show templates (e.g. s5blank)

Further information:
  http://slideshow.rubyforge.org
  
EOS
         exit
    end
  end

  opt.parse!( args )
  
  puts Slideshow.generator

  if opts.list?
    List.new( logger, opts, config ).run   ### todo: remove opts (merge access into config)
  elsif opts.generate?
    GenTemplates.new( logger, opts, config ).run  ###  todo: remove opts
  elsif opts.quick?
    Quick.new( logger, opts, config ).run  ### todo: remove opts
  elsif opts.fetch?
    Fetch.new( logger, opts, config ).run  ### todo: remove opts
  else
    load_plugins  # check for optional plugins/extension in ./lib folder

    args.each do |arg|
      files = find_files( arg )
      files.each do |file| 
       ### fix/todo: reset/clean headers
        Gen.new( logger, opts, config, headers ).create_slideshow( file )
      end
    end
  end
end


end # class Runner

end # module Slideshow