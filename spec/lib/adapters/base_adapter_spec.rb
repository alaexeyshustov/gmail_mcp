require_relative '../../spec_helper'
require_relative '../../../lib/adapters/base_adapter'

RSpec.describe Adapters::BaseAdapter do
  subject(:adapter) { described_class.new }

  describe '#list_messages' do
    it 'raises NotImplementedError' do
      expect { adapter.list_messages }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_message' do
    it 'raises NotImplementedError' do
      expect { adapter.get_message('id') }.to raise_error(NotImplementedError)
    end
  end

  describe '#search_messages' do
    it 'raises NotImplementedError' do
      expect { adapter.search_messages('query') }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_labels' do
    it 'raises NotImplementedError' do
      expect { adapter.get_labels }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_unread_count' do
    it 'raises NotImplementedError' do
      expect { adapter.get_unread_count }.to raise_error(NotImplementedError)
    end
  end

  describe '#modify_labels' do
    it 'raises NotImplementedError' do
      expect { adapter.modify_labels('id') }.to raise_error(NotImplementedError)
    end
  end
end
