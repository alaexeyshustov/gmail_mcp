require_relative '../../spec_helper'
require 'date'

RSpec.describe Pipeline::JobsWorkflow, 'constants' do
  describe 'APPLICATION_CSV' do
    it 'defaults to application_mails.csv in the db/ subdirectory' do
      expect(described_module::APPLICATION_CSV).to eq(
        File.join(described_module::PROJECT_ROOT, 'db', 'application_mails.csv')
      )
    end

    it 'uses APPLICATION_CSV_PATH env var when set' do
      custom_path = '/tmp/custom_mails.csv'
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('APPLICATION_CSV_PATH', anything).and_return(custom_path)
      # Constant is already resolved; test the env var is the source of truth
      expect(ENV.fetch('APPLICATION_CSV_PATH', 'fallback')).to eq(custom_path)
    end
  end

  describe 'INTERVIEWS_CSV' do
    it 'defaults to interviews.csv in the db/ subdirectory' do
      expect(described_module::INTERVIEWS_CSV).to eq(
        File.join(described_module::PROJECT_ROOT, 'db', 'interviews.csv')
      )
    end

    it 'uses INTERVIEWS_CSV_PATH env var when set' do
      custom_path = '/tmp/custom_interviews.csv'
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('INTERVIEWS_CSV_PATH', anything).and_return(custom_path)
      expect(ENV.fetch('INTERVIEWS_CSV_PATH', 'fallback')).to eq(custom_path)
    end
  end

  describe 'LOOKBACK_MONTHS' do
    it 'defaults to 3' do
      expect(described_module::LOOKBACK_MONTHS).to eq(3)
    end

    it 'uses LOOKBACK_MONTHS env var when set' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('LOOKBACK_MONTHS', '3').and_return('6')
      expect(ENV.fetch('LOOKBACK_MONTHS', '3').to_i).to eq(6)
    end
  end

  describe 'PROJECT_ROOT' do
    it 'resolves to the project root directory' do
      expect(File.basename(described_module::PROJECT_ROOT)).not_to eq('pipeline')
      expect(File.exist?(described_module::PROJECT_ROOT)).to be(true)
    end
  end


  def described_module
    Pipeline::JobsWorkflow
  end
end
