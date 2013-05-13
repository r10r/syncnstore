# for ruby 1.8.x that is missing the require_relative method
# see http://stackoverflow.com/questions/4333286/ruby-require-vs-require-relative-best-practice-to-workaround-running-in-both
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

class Syncnstore
    # here comes your code
end


Dir.glob("#{File.dirname(__FILE__)}/syncnstore/**/*.rb").each do |file|
  require_relative file
end
