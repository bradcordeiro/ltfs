# This gem will parse an LTFS schema file, using XMLSimple, and provide
# convenient accessors for metadata about the tape's filesystem and the files
# on it.
#
# Author::      Brad Cordeiro (mailto:me@bradc.com)
# Copyright::   Copyright (c) 2015 Brad Cordeiro
# License::     MIT License

require 'xmlsimple'
require 'date'

# All classes are wrapped the the 'LTFS' module

module LTFS

  # This class represents the entire LTFS index schema, and is used to logically
  # group the metadata about the tape's filesystem with an array of file 
  # metadata for the files on the tape. Tape information is stored on
  # initialization but because parsing file information can be very
  # resource-heavy, file information is not parsed until the first time the 
  # files method is called.
  class LTFSIndex

    # Accepts an LTFS schema file as its only argument
  	def initialize(schema_file)
  		# Nested folders are represented by nested tags in the LTFS schema file,
      # @path_components stores the current path during recursive parsing of
      # folders
      @path_components = ["/"]
  		@array_of_ltfsfiles = []
      @tapedata = LTFSTape.new(XmlSimple.xml_in(schema_file, 'ForceArray' => false, 'KeyToSymbol' => true))
  		@filedata = XmlSimple.xml_in(schema_file, 'ForceArray' => false, 'KeyToSymbol' => true)[:directory][:contents]
  	end

    # Returns an array of file metadata. Each file's metadata is stored in a 
    # an LTFSFile ojbect
    def files
      if @array_of_ltfsfiles.empty? then parse(@filedata) else @array_of_ltfsfiles end
    end

    private
      # Find XML representing files and folders, and pass it to the appropriate method
    	def parse(subdata)
    		if subdata.has_key?(:file)
          handle_files(subdata[:file])
        end
        if subdata.has_key?(:directory)
    		  handle_folders(subdata[:directory])
        end
    	end
  	
      # Traverse deeper into XML representing a folder to parse its contents
      def handle_folders(subdata)
  		  # Single folder
        if subdata.is_a? Hash
  			  @path_components.push(subdata[:name])
  		  	parse(subdata[:contents])
  		  	@path_components.slice!(-1)
          # Multiple folders
  		  elsif subdata.is_a? Array
  		  	subdata.each do |f|
  		  		@path_components.push(f[:name])
  		  		parse(f[:contents])
  		  		@path_components.slice!(-1)
  		  	end
  		  end
      end
  
      # Parse XML respresenting a file on tape into an LTFSFile object, and add it to an array of files
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

  # Represents information about a tape's filesystem
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

  # Represents a file in an LTFS schema
  class LTFSFile
  	# The name of the file, as stored on the tape
    attr_reader :basename
    # Length, in bytes, of the file on tape
    attr_reader :size
    # Returns the birth time (creation time) for the file.
    attr_reader :birthtime
    # Returns the change time (that is, the time directory information about the
    # file was changed, not the file itself).
    attr_reader :ctime
    # Returns the modification time for the named file as a DateTime object.
    attr_reader :mtime
    # Returns a Ruby DateTime object containing the time the file was last accessed
    attr_reader :atime
    # Returns the last access time for this file as an object of class DateTime.
    attr_reader :backuptime
    # Returnss the file's unique ID number on the tape
    attr_reader :fileuid
    # Returns the string representation of the path
    attr_reader :path
    # fileoffset
    attr_reader :fileoffset
    attr_reader :partition
    attr_reader :startblock
    attr_reader :byteoffset
    attr_reader :bytecount
    attr_reader :editable?

    alias_method :length, :size
    alias_method :uid, :fileuid
    alias_method :filepath, :path
  	
    # :nodoc:
    def initialize(input, pathname)
  		@path = File.join(pathname)
  		@basename = input[:name]
  		@birthtime = DateTime.parse(input[:creationtime])
  		@ctime = DateTime.parse(input[:changetime])
  		@mtime = DateTime.parse(input[:modifytime])
  		@atime = DateTime.parse(input[:accesstime])
  		@backuptime = DateTime.parse(input[:backuptime])
  		@fileuid = input[:fileuid]
  		
      extentinfo = LTFSExtentInfo.new(input[:extentinfo])
      @fileoffset = extentinfo.fileoffset
      @partition = extentinfo.partition
      @startblock = extentinfo.startblock
      @byteoffset = extentinfo.byteoffset
      @bytecount = extentinfo.bytecount

      input[:length].nil? ? @length = 0 : @length = input[:length]
  		input[:editable] == "true" ? @editable = true : @editable = false
  	end

  # Poor tape-writing practice causes large variations in Extent information about an LTFSFile, so this
  # part of information has been abstracted to its own class to do some sanity checks.
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
    
      # Poorly written tapes will have multiple values for the same field, so here we create a
      # comma-separated string of all of the values.
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
        @partition = partitions.join(',')
      end

  end
end