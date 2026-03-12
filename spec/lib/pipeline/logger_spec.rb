require_relative '../../spec_helper'
require 'tmpdir'

RSpec.describe Pipeline::Logger do
  let(:output) { StringIO.new }

  describe '#info' do
    subject(:logger) { described_class.new(level: :info, output: output) }

    it 'writes an INFO message to the configured output' do
      logger.info('hello world')
      expect(output.string).to include('[INFO]').and include('hello world')
    end

    it 'includes the [Pipeline] prefix' do
      logger.info('step start')
      expect(output.string).to start_with('[Pipeline]')
    end

    it 'suppresses DEBUG messages at the info level' do
      logger.debug('verbose detail')
      expect(output.string).to be_empty
    end
  end

  describe '#debug' do
    subject(:logger) { described_class.new(level: :debug, output: output) }

    it 'writes a DEBUG message when level is :debug' do
      logger.debug('verbose detail')
      expect(output.string).to include('[DEBUG]').and include('verbose detail')
    end

    it 'also writes INFO messages at debug level' do
      logger.info('step start')
      expect(output.string).to include('[INFO]').and include('step start')
    end
  end

  describe '#warn' do
    subject(:logger) { described_class.new(level: :warn, output: output) }

    it 'writes a WARN message' do
      logger.warn('something odd')
      expect(output.string).to include('[WARN]').and include('something odd')
    end

    it 'suppresses INFO messages at warn level' do
      logger.info('step start')
      expect(output.string).to be_empty
    end
  end

  describe '#error' do
    subject(:logger) { described_class.new(level: :error, output: output) }

    it 'writes an ERROR message' do
      logger.error('boom')
      expect(output.string).to include('[ERROR]').and include('boom')
    end

    it 'suppresses WARN messages at error level' do
      logger.warn('minor issue')
      expect(output.string).to be_empty
    end
  end

  describe 'default level' do
    it 'defaults to :info (suppresses debug)' do
      logger = described_class.new(output: output)
      logger.debug('should be hidden')
      logger.info('should be visible')
      expect(output.string).not_to include('should be hidden')
      expect(output.string).to include('should be visible')
    end
  end

  describe 'level as string' do
    it 'accepts a string level' do
      logger = described_class.new(level: 'debug', output: output)
      logger.debug('string level works')
      expect(output.string).to include('string level works')
    end
  end

  describe 'log_file: option' do
    it 'duplicates log output to the specified file' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'pipeline.log')
        logger   = described_class.new(output: output, log_file: log_path)
        logger.info('written to both')
        expect(output.string).to include('written to both')
        expect(File.read(log_path)).to include('written to both')
      end
    end

    it 'appends to an existing log file' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'pipeline.log')
        File.write(log_path, "existing content\n")
        logger = described_class.new(output: output, log_file: log_path)
        logger.info('new entry')
        content = File.read(log_path)
        expect(content).to include('existing content')
        expect(content).to include('new entry')
      end
    end

    it 'honours the configured severity level for both outputs' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'pipeline.log')
        logger   = described_class.new(level: :warn, output: output, log_file: log_path)
        logger.info('should be suppressed')
        logger.warn('should appear')
        expect(output.string).not_to include('should be suppressed')
        expect(output.string).to include('should appear')
        expect(File.read(log_path)).not_to include('should be suppressed')
        expect(File.read(log_path)).to include('should appear')
      end
    end
  end
end
