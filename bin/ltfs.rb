require 'xmlsimple'

class LTFSIndex

	def initialize(file)
		@path_components = ["/"]
		@array_of_ltfsfiles = []
		@tapedata = LTFSTape.new(XmlSimple.xml_in(file, 'ForceArray' => false, 'KeyToSymbol' => true))
		@filedata = XmlSimple.xml_in(file, 'ForceArray' => false, 'KeyToSymbol' => true)[:directory][:contents]
	end

  def files
    if @array_of_ltfsfiles.empty? then parse(@filedata) else @array_of_ltfsfiles end
  end

  private
  	def parse(subdata)
  		handle_files(subdata[:file]) if subdata.has_key?(:file)
  		handle_folders(subdata[:directory]) if subdata.has_key?(:directory)
  	end
  	
    def handle_folders(subdata)
		  if subdata.is_a? Hash
			  @path_components.push(subdata[:name])
		  	parse(subdata[:contents])
		  	@path_components.slice!(-1)
		  elsif subdata.is_a? Array
		  	subdata.each do |f|
		  		@path_components.push(f[:name])
		  		parse(f[:contents])
		  		@path_components.slice!(-1)
		  	end
		  end
    end

  def handle_files(subdata)
		# single file in a folder
		if subdata.is_a? Hash
			@array_of_ltfsfiles.push(LTFSFile.new(subdata, @tapedata.volumeuuid, @path_components))
		# multiple files in a folder
		elsif subdata.is_a? Array
			subdata.each { |f| @array_of_ltfsfiles.push(LTFSFile.new(f, @tapedata.volumeuuid, @path_components)) }
		end
  end

end

class LTFSTape
	attr_reader :version, :creator, :volumeuuid, :generation, :updatetime, 
							:indexpartition, :indexstartblock, :previousgenerationpartition, 
							:previousgenerationstartblock, :allowpolicyupdate, :highestfileuid, 
							:volumename
	  
	def initialize(input)
		@volumeuuid = input[:volumeuuid]
		@version = input["version"] # attribute, not key, in the XML, so not a symbol here
		@creator = input[:creator]
		@generation = input[:generationnumber]
		@updatetime = input[:updatetime]
		@indexpartition = input[:location][:partition]
		@indexstartblock = input[:location][:startblock]
		@previousgenerationpartition = input[:previousgenerationlocation][:partition]
		@previousgenerationstartblock = input[:previousgenerationlocation][:startblock]
		@allowpolicyupdate == "true" ? true : false
		@highestfileuid = input[:highestfileuid]
		input[:directory][:name].is_a?(Hash) ? @volumename = "Unnamed Tape" : @volumename = input[:directory][:name]
	end

end

class LTFSFile
	attr_reader :filename, :length, :editable, :creationtime, :changetime,
    	        :modifytime, :accesstime, :backuptime, :fileuid, :filepath,
    	        :volumeuuid

	def initialize(input, volumeuuid, pathname)
		@volumeuuid = volumeuuid
		@filepath = File.join(pathname)
		@filename = input[:name]
		@editable = input[:readonly]
		@creationtime = input[:creationtime]
		@changetime = input[:changetime]
		@modifytime = input[:modifytime]
		@accesstime = input[:accesstime]
		@backuptime = input[:backuptime]
		@fileuid = input[:fileuid]
		if input[:length].nil? then @length = 0 else @length = input[:length] end
		@extentinfo = LTFSExtentInfo.new(input[:extentinfo])
	end
	
	def to_s
	  File.join(@filepath, @filename)
	end
	
	def fileoffset
	  @extentinfo.fileoffset
	end
	
	def partition
		@extentinfo.partition
	end
  
	def startblock
		@extentinfo.startblock
	end

	def byteoffset
   @extentinfo.byteoffset
	end

	def bytecount
   @extentinfo.bytecount
	end

end

class LTFSExtentInfo

  attr_reader :bytecount, :byteoffset, :startblock, :fileoffset, :partition
  
  def initialize(extentinfo)
    @extentinfo = extentinfo
    if @extentinfo.nil? or @extentinfo[:extent].nil?
      handle_missing_extent
    elsif @extentinfo[:extent].is_a?(Array)
      handle_extent_array
    else
      handle_single_values
    end    
  end
  
  private
    # Handles a normal LTFS schema, with a single value for all extent fields
    def handle_single_values
      @bytecount = @extentinfo[:extent][:bytecount].to_i || 0
      @byteoffset = @extentinfo[:extent][:byteoffset].to_i || 0
      @startblock = @extentinfo[:extent][:startblock].to_i || 0
      @fileoffset = @extentinfo[:extent][:fileoffset].to_i || 0
      @partition = @extentinfo[:extent][:partition].to_i || 'b'    
    end
   
     # If extent fields are missing, assign numberical fields to 0 and partition to the default 'b'
    def handle_missing_extent
      @bytecount, @byteoffset, @startblock, @fileoffset, @partition = 0, 0, 0, 0, 'b'
    end
    
    # Poorly written tapes will have multiple values for the same field
    def handle_extent_array
      bytecounts, byteoffsets, startblocks, fileoffsets, partitions = [], [], [], [], []
      @extentinfo[:extent].each do |f|
        bytecounts << f[:bytecount]
        byteoffsets << f[:byteoffset]
        startblocks << f[:startblock]
        fileoffsets << f[:fileoffset]
        partitions << f[:partition]
      end
      @bytecount = bytecounts.join(',')
      @byteoffset = byteoffsets.join(',')
      @startblock = startblocks.join(',')
      @fileoffset = fileoffsets.join(',')
      @partition = partitions.join('.')
    end

end∑