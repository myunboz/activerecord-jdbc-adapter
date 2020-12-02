module ActiveRecord
  class << Base
    m = Module.new do
      # Allow adapters to provide their own {#reset_column_information} method.
      # @note This only affects the current thread's connection.
      def reset_column_information # :nodoc:
        # invoke the adapter-specific reset_column_information method
        connection.reset_column_information if connection.respond_to?(:reset_column_information)
        super
      end
    end

    self.prepend(m)
  end

  # Represents exceptions that have propagated up through the JDBC API.
  class JDBCError < ActiveRecordError
    # The vendor code or error number that came from the database.
    # @note writer being used by the Java API
    attr_accessor :errno
    # The full Java SQLException object that was raised.
    # @note writer being used by the Java API
    attr_accessor :sql_exception

    attr_reader :original_exception, :raw_backtrace

    def initialize(message = nil, original_exception = nil) # $!
      super(message)
      @original_exception = original_exception
    end

    def set_backtrace(backtrace)
      @raw_backtrace = backtrace
      if nested = original_exception
        backtrace = backtrace - (
          nested.respond_to?(:raw_backtrace) ? nested.raw_backtrace : nested.backtrace )
        backtrace << "#{nested.backtrace.first}: #{nested.message} (#{nested.class.name})"
        backtrace += nested.backtrace[1..-1] || []
      end
      super(backtrace)
    end

  end
end