require_relative '../../spec_helper'

require 'tempfile'
require 'csv'
require 'json'

RSpec.describe Tools::ManageCsv do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmpdir) }

  def csv_path(name = 'test.csv')
    File.join(tmpdir, name)
  end

  def write_csv(path, headers, rows)
    CSV.open(path, 'w') do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  def read_csv(path)
    CSV.read(path, headers: true)
  end

  # ---------------------------------------------------------------------------
  # action: create
  # ---------------------------------------------------------------------------
  describe 'action: create' do
    it 'creates a CSV with headers only' do
      path = csv_path('new.csv')
      result = described_class.new.call(
        action:    'create',
        file_path: path,
        data:      '["name","email","status"]'
      )
      expect(result[:status]).to eq('created')
      expect(result[:headers]).to eq(%w[name email status])
      expect(result[:row_count]).to eq(0)
      expect(File.exist?(path)).to be true

      table = read_csv(path)
      expect(table.headers).to eq(%w[name email status])
      expect(table.size).to eq(0)
    end

    it 'creates a CSV with headers and initial rows' do
      path = csv_path('with_rows.csv')
      rows_data = {
        'headers' => %w[name email],
        'rows'    => [%w[Alice alice@x.com], %w[Bob bob@x.com]]
      }
      result = described_class.new.call(
        action:    'create',
        file_path: path,
        data:      JSON.generate(rows_data)
      )
      expect(result[:status]).to eq('created')
      expect(result[:row_count]).to eq(2)

      table = read_csv(path)
      expect(table.size).to eq(2)
      expect(table[0]['name']).to eq('Alice')
      expect(table[1]['email']).to eq('bob@x.com')
    end

    it 'raises an error when data is missing for create' do
      expect {
        described_class.new.call(action: 'create', file_path: csv_path)
      }.to raise_error(ArgumentError, /data is required/)
    end
  end

  # ---------------------------------------------------------------------------
  # action: read
  # ---------------------------------------------------------------------------
  describe 'action: read' do
    it 'reads all rows from a CSV' do
      path = csv_path
      write_csv(path, %w[name email], [%w[Alice a@x.com], %w[Bob b@x.com]])

      result = described_class.new.call(action: 'read', file_path: path)
      expect(result[:headers]).to eq(%w[name email])
      expect(result[:rows].size).to eq(2)
      expect(result[:rows][0]).to eq({ 'name' => 'Alice', 'email' => 'a@x.com' })
    end

    it 'filters rows by column value' do
      path = csv_path
      write_csv(path, %w[name status], [%w[Alice active], %w[Bob inactive], %w[Carol active]])

      result = described_class.new.call(
        action:       'read',
        file_path:    path,
        column_name:  'status',
        column_value: 'active'
      )
      expect(result[:rows].size).to eq(2)
      expect(result[:rows].map { |r| r['name'] }).to eq(%w[Alice Carol])
    end

    it 'raises an error when the file does not exist' do
      expect {
        described_class.new.call(action: 'read', file_path: csv_path('missing.csv'))
      }.to raise_error(ArgumentError, /not found/)
    end
  end

  # ---------------------------------------------------------------------------
  # action: add_rows
  # ---------------------------------------------------------------------------
  describe 'action: add_rows' do
    it 'appends rows to an existing CSV' do
      path = csv_path
      write_csv(path, %w[name email], [%w[Alice a@x.com]])

      rows_to_add = [%w[Bob b@x.com], %w[Carol c@x.com]]
      result = described_class.new.call(
        action:    'add_rows',
        file_path: path,
        data:      JSON.generate(rows_to_add)
      )
      expect(result[:status]).to eq('rows_added')
      expect(result[:rows_added]).to eq(2)
      expect(result[:total_rows]).to eq(3)

      table = read_csv(path)
      expect(table.size).to eq(3)
      expect(table[2]['name']).to eq('Carol')
    end

    it 'appends rows given as hashes' do
      path = csv_path
      write_csv(path, %w[name email], [%w[Alice a@x.com]])

      rows_to_add = [{ 'name' => 'Bob', 'email' => 'b@x.com' }]
      result = described_class.new.call(
        action:    'add_rows',
        file_path: path,
        data:      JSON.generate(rows_to_add)
      )
      expect(result[:rows_added]).to eq(1)

      table = read_csv(path)
      expect(table[1]['name']).to eq('Bob')
      expect(table[1]['email']).to eq('b@x.com')
    end

    it 'raises an error when data is missing' do
      path = csv_path
      write_csv(path, %w[name email], [])
      expect {
        described_class.new.call(action: 'add_rows', file_path: path)
      }.to raise_error(ArgumentError, /data is required/)
    end
  end

  # ---------------------------------------------------------------------------
  # action: add_columns
  # ---------------------------------------------------------------------------
  describe 'action: add_columns' do
    it 'adds new columns with default values' do
      path = csv_path
      write_csv(path, %w[name email], [%w[Alice a@x.com], %w[Bob b@x.com]])

      result = described_class.new.call(
        action:    'add_columns',
        file_path: path,
        data:      JSON.generate({ 'status' => 'pending', 'age' => '' })
      )
      expect(result[:status]).to eq('columns_added')
      expect(result[:columns_added]).to eq(%w[status age])

      table = read_csv(path)
      expect(table.headers).to eq(%w[name email status age])
      expect(table[0]['status']).to eq('pending')
      expect(table[1]['age']).to eq('')
    end

    it 'skips columns that already exist' do
      path = csv_path
      write_csv(path, %w[name email], [%w[Alice a@x.com]])

      result = described_class.new.call(
        action:    'add_columns',
        file_path: path,
        data:      JSON.generate({ 'email' => 'default', 'city' => 'unknown' })
      )
      expect(result[:columns_added]).to eq(%w[city])
      expect(result[:columns_skipped]).to eq(%w[email])

      table = read_csv(path)
      expect(table.headers).to eq(%w[name email city])
      expect(table[0]['city']).to eq('unknown')
      # Existing 'email' column not overwritten
      expect(table[0]['email']).to eq('a@x.com')
    end
  end

  # ---------------------------------------------------------------------------
  # action: update_rows
  # ---------------------------------------------------------------------------
  describe 'action: update_rows' do
    it 'updates matching rows by column value' do
      path = csv_path
      write_csv(path, %w[name email status], [
        %w[Alice a@x.com active],
        %w[Bob   b@x.com inactive],
        %w[Carol c@x.com active]
      ])

      updates = { 'status' => 'archived' }
      result = described_class.new.call(
        action:       'update_rows',
        file_path:    path,
        column_name:  'status',
        column_value: 'active',
        data:         JSON.generate(updates)
      )
      expect(result[:status]).to eq('rows_updated')
      expect(result[:rows_updated]).to eq(2)

      table = read_csv(path)
      expect(table[0]['status']).to eq('archived')
      expect(table[1]['status']).to eq('inactive')
      expect(table[2]['status']).to eq('archived')
    end

    it 'updates multiple columns at once' do
      path = csv_path
      write_csv(path, %w[name email status notes], [
        %w[Alice a@x.com active none],
        %w[Bob   b@x.com active none]
      ])

      updates = { 'status' => 'done', 'notes' => 'completed' }
      result = described_class.new.call(
        action:       'update_rows',
        file_path:    path,
        column_name:  'name',
        column_value: 'Alice',
        data:         JSON.generate(updates)
      )
      expect(result[:rows_updated]).to eq(1)

      table = read_csv(path)
      expect(table[0]['status']).to eq('done')
      expect(table[0]['notes']).to eq('completed')
      # Bob untouched
      expect(table[1]['status']).to eq('active')
    end

    it 'raises when column_name or column_value is missing' do
      path = csv_path
      write_csv(path, %w[name], [%w[Alice]])
      expect {
        described_class.new.call(
          action:    'update_rows',
          file_path: path,
          data:      '{"name": "Bob"}'
        )
      }.to raise_error(ArgumentError, /column_name and column_value are required/)
    end

    it 'returns zero rows_updated when no rows match' do
      path = csv_path
      write_csv(path, %w[name status], [%w[Alice active]])

      result = described_class.new.call(
        action:       'update_rows',
        file_path:    path,
        column_name:  'name',
        column_value: 'Nobody',
        data:         '{"status": "x"}'
      )
      expect(result[:rows_updated]).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # unknown action
  # ---------------------------------------------------------------------------
  describe 'unknown action' do
    it 'raises ArgumentError' do
      expect {
        described_class.new.call(action: 'delete', file_path: csv_path)
      }.to raise_error(ArgumentError, /Unknown action/)
    end
  end

  # ---------------------------------------------------------------------------
  # tool_name
  # ---------------------------------------------------------------------------
  describe '.tool_name' do
    it 'is "manage_csv"' do
      expect(described_class.tool_name).to eq('manage_csv')
    end
  end
end
