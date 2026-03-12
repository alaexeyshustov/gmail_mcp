require_relative '../../../spec_helper'

RSpec.describe Pipeline::Agents::ReconcileInterviewsAgent do
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

  it 'has instructions that mention manage_csv' do
    instructions = described_class.instructions
    expect(instructions).to include('manage_csv')
  end

  it 'has instructions that mention interviews.csv or status' do
    instructions = described_class.instructions
    expect(instructions).to include('interviews').or include('status')
  end

  it 'has instructions mentioning status values' do
    instructions = described_class.instructions
    expect(instructions).to include('rejected').or include('offer_received').or include('having_interviews')
  end

  it 'ask returns the chat response' do
    VCR.use_cassette('agents/reconcile_interviews_agent/ask') do
      result = described_class.new.ask('ping')
      expect(result.content).to eq('pong')
    end
  end
end
