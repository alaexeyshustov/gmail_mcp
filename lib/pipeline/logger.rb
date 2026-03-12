require 'logger'

module Pipeline
  # Centralised logger for the pipeline. Wraps Ruby's standard Logger with a
  # fixed format and convenient level helpers.
  #
  # Levels (ascending severity):
  #   :debug — verbose per-step detail (counts, IDs, etc.)
  #   :info  — step start/end banners (default)
  #   :warn  — non-fatal anomalies
  #   :error — failures
  #
  # Usage:
  #   logger = Pipeline::Logger.new(level: :debug)
  #   logger.info  "Step 1: Initialising CSV database..."
  #   logger.debug "  cutoff_date=2026-01-01, existing_ids=42"
  #
  # Pass log_file: to duplicate all output to a file in addition to the primary
  # output stream (tee behaviour):
  #   logger = Pipeline::Logger.new(log_file: 'log/pipeline.log')
  class Logger
    LEVELS = %w[debug info warn error].freeze

    # Forwards write/flush/close to every supplied IO target simultaneously,
    # providing tee-like behaviour for the underlying Ruby Logger.
    class MultiIO
      def initialize(*targets)
        @targets = targets
      end

      def write(*args)
        @targets.each do |t|
          t.write(*args)
          t.flush if t.respond_to?(:flush)
        end
      end

      def flush
        @targets.each { |t| t.flush if t.respond_to?(:flush) }
      end

      def close
        @targets.each(&:close)
      end
    end

    def initialize(level: :info, output: $stderr, log_file: nil)
      dest = if log_file
               MultiIO.new(output, File.open(log_file, 'a'))
             else
               output
             end
      @logger           = ::Logger.new(dest)
      @logger.level     = ::Logger.const_get(level.to_s.upcase)
      @logger.formatter = proc do |severity, _time, _prog, msg|
        "[Pipeline] [#{severity}] #{msg}\n"
      end
    end

    LEVELS.each do |lvl|
      define_method(lvl) do |*args, &block|
        @logger.send(lvl, *args, &block)
      end
    end
  end
end
