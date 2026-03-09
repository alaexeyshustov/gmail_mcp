require 'fast_mcp'
require 'csv'
require 'json'

module Tools
  class ManageCsv < FastMcp::Tool
    tool_name 'manage_csv'
    description 'Parse, create, and update CSV files. ' \
                'Supports actions: "read" (parse a CSV, optionally filter by column), ' \
                '"create" (new CSV with headers and optional rows), ' \
                '"add_rows" (append rows), ' \
                '"add_columns" (add new columns with defaults), ' \
                '"update_rows" (update rows matching a column value).'

    arguments do
      required(:action).filled(:string)
        .description('Action to perform: "read", "create", "add_rows", "add_columns", "update_rows"')
      required(:file_path).filled(:string)
        .description('Absolute path to the CSV file')
      optional(:data).filled(:string)
        .description(
          'JSON-encoded data. Meaning varies by action: ' \
          'create → ["col1","col2"] or {"headers":["col1"],"rows":[["v1"]]}; ' \
          'add_rows → [["v1","v2"]] or [{"col1":"v1"}]; ' \
          'add_columns → {"new_col":"default_value"}; ' \
          'update_rows → {"col_to_set":"new_value"}'
        )
      optional(:column_name).filled(:string)
        .description('Column name to match (for "update_rows" or filtering in "read")')
      optional(:column_value).filled(:string)
        .description('Column value to match (for "update_rows" or filtering in "read")')
    end

    def call(action:, file_path:, data: nil, column_name: nil, column_value: nil)
      case action
      when 'read'       then read_csv(file_path, column_name, column_value)
      when 'create'     then create_csv(file_path, data)
      when 'add_rows'   then add_rows(file_path, data)
      when 'add_columns' then add_columns(file_path, data)
      when 'update_rows' then update_rows(file_path, data, column_name, column_value)
      else
        raise ArgumentError, "Unknown action: #{action}. Use read, create, add_rows, add_columns, or update_rows."
      end
    end

    class << self
      attr_accessor :registry
    end

    private

    # -------------------------------------------------------------------------
    # read
    # -------------------------------------------------------------------------
    def read_csv(file_path, column_name, column_value)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

      table = CSV.read(file_path, headers: true)
      rows = table.map(&:to_h)

      if column_name && column_value
        rows = rows.select { |row| row[column_name] == column_value }
      end

      { headers: table.headers, rows: rows, row_count: rows.size }
    end

    # -------------------------------------------------------------------------
    # create
    # -------------------------------------------------------------------------
    def create_csv(file_path, data)
      raise ArgumentError, 'data is required for create action' if data.nil? || data.strip.empty?

      parsed = JSON.parse(data)

      if parsed.is_a?(Array)
        # Simple array of headers
        headers = parsed
        rows = []
      elsif parsed.is_a?(Hash)
        headers = parsed['headers']
        rows = parsed.fetch('rows', [])
      else
        raise ArgumentError, 'data must be a JSON array of headers or {"headers": [...], "rows": [...]}'
      end

      CSV.open(file_path, 'w') do |csv|
        csv << headers
        rows.each { |row| csv << row }
      end

      { status: 'created', file_path: file_path, headers: headers, row_count: rows.size }
    end

    # -------------------------------------------------------------------------
    # add_rows
    # -------------------------------------------------------------------------
    def add_rows(file_path, data)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)
      raise ArgumentError, 'data is required for add_rows action' if data.nil? || data.strip.empty?

      table = CSV.read(file_path, headers: true)
      headers = table.headers
      new_rows = JSON.parse(data)

      new_rows.each do |row|
        if row.is_a?(Hash)
          table << headers.map { |h| row[h] }
        else
          table << row
        end
      end

      CSV.open(file_path, 'w') do |csv|
        csv << headers
        table.each { |r| csv << r.fields }
      end

      { status: 'rows_added', rows_added: new_rows.size, total_rows: table.size }
    end

    # -------------------------------------------------------------------------
    # add_columns
    # -------------------------------------------------------------------------
    def add_columns(file_path, data)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)
      raise ArgumentError, 'data is required for add_columns action' if data.nil? || data.strip.empty?

      table = CSV.read(file_path, headers: true)
      columns = JSON.parse(data)
      existing = table.headers

      added = []
      skipped = []

      columns.each do |col_name, default_value|
        if existing.include?(col_name)
          skipped << col_name
        else
          added << col_name
          table.each { |row| row[col_name] = default_value }
        end
      end

      new_headers = existing + added

      CSV.open(file_path, 'w') do |csv|
        csv << new_headers
        table.each { |row| csv << new_headers.map { |h| row[h] } }
      end

      result = { status: 'columns_added', columns_added: added, headers: new_headers }
      result[:columns_skipped] = skipped unless skipped.empty?
      result
    end

    # -------------------------------------------------------------------------
    # update_rows
    # -------------------------------------------------------------------------
    def update_rows(file_path, data, column_name, column_value)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)
      raise ArgumentError, 'data is required for update_rows action' if data.nil? || data.strip.empty?
      if column_name.nil? || column_value.nil?
        raise ArgumentError, 'column_name and column_value are required for update_rows action'
      end

      table = CSV.read(file_path, headers: true)
      updates = JSON.parse(data)
      updated_count = 0

      table.each do |row|
        if row[column_name] == column_value
          updates.each { |col, val| row[col] = val }
          updated_count += 1
        end
      end

      CSV.open(file_path, 'w') do |csv|
        csv << table.headers
        table.each { |row| csv << row.fields }
      end

      { status: 'rows_updated', rows_updated: updated_count, total_rows: table.size }
    end
  end
end
