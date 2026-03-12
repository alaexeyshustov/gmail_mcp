require_relative '../../../spec_helper'

RSpec.describe Pipeline::Agents::LabelAndStoreAgent do
  before { RubyLLM.configure { |c| c.mistral_api_key = 'test-key' } }

  it 'inherits from RubyLLM::Agent' do
    expect(described_class.ancestors).to include(RubyLLM::Agent)
  end

  it 'declares TOOLS as ["add_labels", "manage_csv"]' do
    expect(described_class::TOOLS).to eq(%w[add_labels manage_csv])
  end

  it 'has a model configured' do
    expect(described_class.chat_kwargs[:model]).not_to be_nil
  end

  it 'has instructions that mention add_labels' do
    instructions = described_class.instructions
    expect(instructions).to include('add_labels')
  end

  it 'has instructions that mention manage_csv' do
    instructions = described_class.instructions
    expect(instructions).to include('manage_csv')
  end

  it 'has instructions that mention company and job_title extraction' do
    instructions = described_class.instructions
    expect(instructions).to include('company').or include('job_title')
  end

  it 'has instructions that mention action values' do
    instructions = described_class.instructions
    expect(instructions).to include('Applied').or include('Rejection').or include('Interview')
  end

  it 'ask returns the chat response' do
    VCR.use_cassette('agents/label_and_store_agent/ask') do
      result = described_class.new.ask('ping')
      expect(result.content).to eq('pong')
    end
  end
end
