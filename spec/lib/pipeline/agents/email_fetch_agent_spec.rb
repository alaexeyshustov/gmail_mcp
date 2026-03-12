require_relative '../../../spec_helper'

RSpec.describe Pipeline::Agents::EmailFetchAgent do
  before { RubyLLM.configure { |c| c.mistral_api_key = 'test-key' } }

  it 'inherits from RubyLLM::Agent' do
    expect(described_class.ancestors).to include(RubyLLM::Agent)
  end

  it 'declares TOOLS as ["list_emails"]' do
    expect(described_class::TOOLS).to eq(%w[list_emails])
  end

  it 'has a model configured' do
    expect(described_class.chat_kwargs[:model]).not_to be_nil
  end

  it 'has instructions that mention list_emails' do
    instructions = described_class.instructions
    expect(instructions).to include('list_emails')
  end

  it 'has instructions that mention pagination / offset' do
    instructions = described_class.instructions
    expect(instructions).to include('offset').or include('paginate').or include('pagination')
  end

  it 'ask returns the chat response' do
    VCR.use_cassette('agents/email_fetch_agent/ask') do
      result = described_class.new.ask('ping')
      expect(result.content).to eq('pong')
    end
  end
end
