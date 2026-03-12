require_relative '../../../spec_helper'

RSpec.describe Pipeline::Agents::ClassifyAndFilterAgent do
  before { RubyLLM.configure { |c| c.mistral_api_key = 'test-key' } }

  it 'inherits from RubyLLM::Agent' do
    expect(described_class.ancestors).to include(RubyLLM::Agent)
  end

  it 'declares TOOLS as ["classify_emails"]' do
    expect(described_class::TOOLS).to eq(%w[classify_emails])
  end

  it 'has a model configured' do
    expect(described_class.chat_kwargs[:model]).not_to be_nil
  end

  it 'has instructions that mention classify_emails' do
    instructions = described_class.instructions
    expect(instructions).to include('classify_emails')
  end

  it 'has instructions that mention job-related tags' do
    instructions = described_class.instructions
    expect(instructions).to include('job').or include('interview').or include('application')
  end

  it 'has instructions that mention batching' do
    instructions = described_class.instructions
    expect(instructions).to include('batch').or include('20')
  end

  it 'ask returns the chat response' do
    VCR.use_cassette('agents/classify_and_filter_agent/ask') do
      result = described_class.new.ask('ping')
      expect(result.content).to eq('pong')
    end
  end
end
