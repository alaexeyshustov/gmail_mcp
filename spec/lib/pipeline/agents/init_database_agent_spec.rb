require_relative '../../../spec_helper'

RSpec.describe Pipeline::Agents::InitDatabaseAgent do
  before { RubyLLM.configure { |c| c.mistral_api_key = 'test-key' } }

  it 'inherits from RubyLLM::Agent' do
    expect(described_class.ancestors).to include(RubyLLM::Agent)
  end

  it 'declares TOOLS as ["manage_csv"]' do
    expect(described_class::TOOLS).to eq(%w[manage_csv])
  end

  it 'has a model configured' do
    expect(described_class.chat_kwargs[:model]).not_to be_nil
  end

  it 'has instructions that mention CSV and date (latest_date)' do
    instructions = described_class.instructions
    expect(instructions).to include('CSV').or include('csv')
    expect(instructions).to include('latest_date').or include('date')
  end

  it 'has instructions that mention existing_ids' do
    instructions = described_class.instructions
    expect(instructions).to include('existing_ids').or include('email_id')
  end

  it 'ask returns the chat response' do
    VCR.use_cassette('agents/init_database_agent/ask') do
      result = described_class.new.ask('ping')
      expect(result.content).to eq('pong')
    end
  end
end
