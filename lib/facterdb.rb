require 'facter'
require 'jgrep'

module FacterDB

  # @return [String] -  returns a giant incomprehensible string of concatenated json data
  def self.database
    @database ||= "[#{facterdb_fact_files.map { |f| File.read(f) }.join(',')}]\n"
  end

  # @return [Boolean] - returns true if we should use the default facterdb database, false otherwise
  # @note If the user passes anything to the FACTERDB_SKIP_DEFAULTDB environment variable we assume
  # they want to skip the default db
  def self.use_defaultdb?
    ENV['FACTERDB_SKIP_DEFAULTDB'].nil?
  end

  # @return [Array[String]] -  list of all files found in the default facterdb facts path
  def self.default_fact_files
    return [] unless use_defaultdb?
    proj_root = File.join(File.dirname(File.dirname(__FILE__)))
    facts_dir = File.expand_path(File.join(proj_root, 'facts'))
    Dir.glob(File.join(facts_dir, "**", '*.facts'))
  end

  # @return [Array[String]] -  list of all files found in the user supplied facterdb facts path
  # @param fact_paths [String] - a comma separated list of paths to search for fact files
  def self.external_fact_files(fact_paths = ENV['FACTERDB_SEARCH_PATHS'])
    fact_paths ||= ''
    return [] if fact_paths.empty?
    paths = fact_paths.split(File::PATH_SEPARATOR).map do |fact_path|
      unless File.directory?(fact_path)
        warn("[FACTERDB] Ignoring external facts path #{fact_path} as it is not a directory")
        next nil
      end
      fact_path = fact_path.gsub(File::ALT_SEPARATOR, File::SEPARATOR) if File::ALT_SEPARATOR
      File.join(fact_path.strip, '**', '*.facts')
    end.compact
    Dir.glob(paths)
  end

  # @return [Array[String]] -  list of all files found in the default facterdb facts path and user supplied path
  # @note external fact files supplied by the user will take precedence over default fact files found in this gem
  def self.facterdb_fact_files
    (external_fact_files + default_fact_files).uniq
  end

  def self.get_os_facts(facter_version='*', filter=[])
    if facter_version == '*'
      if filter.is_a?(Array)
        filter_str = filter.map { |f| f.map { |k,v | "#{k}=#{v}" }.join(' and ') }.join(' or ')
      elsif filter.is_a?(Hash)
        filter_str = filter.map { |k,v | "#{k}=#{v}" }.join(' and ')
      elsif filter.is_a?(String)
        filter_str = filter
      else
        raise 'filter must be either an Array a Hash or a String'
      end
    else
      if filter.is_a?(Array)
        filter_str = "facterversion=/^#{facter_version}/ and (#{filter.map { |f| f.map { |k,v | "#{k}=#{v}" }.join(' and ') }.join(' or ')})"
      elsif filter.is_a?(Hash)
        filter_str = "facterversion=/^#{facter_version}/ and (#{filter.map { |k,v | "#{k}=#{v}" }.join(' and ')})"
      elsif filter.is_a?(String)
        filter_str = "facterversion=/^#{facter_version}/ and (#{filter})"
      else
        raise 'filter must be either an Array a Hash or a String'
      end
    end

    warn "[DEPRECATION] `get_os_facts` is deprecated. Please use `get_facts(#{filter_str})` instead."

    get_facts(filter_str)
  end

  def self.get_facts(filter=nil)
    if filter.is_a?(Array)
      filter_str = '(' + filter.map { |f| f.map { |k,v | "#{k}=#{v}" }.join(' and ') }.join(') or (') + ')'
    elsif filter.is_a?(Hash)
      filter_str = filter.map { |k,v | "#{k}=#{v}" }.join(' and ')
    elsif filter.is_a?(String)
      filter_str = filter
    elsif filter == nil
      filter_str = ''
    else
      raise 'filter must be either an Array a Hash or a String'
    end
    JGrep.jgrep(database, filter_str).map { |hash| Hash[hash.map{ |k, v| [k.to_sym, v] }] }
  end
end
