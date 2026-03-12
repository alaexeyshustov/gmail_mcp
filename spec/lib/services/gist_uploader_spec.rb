require_relative '../../spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe GistUploader do
  let(:token)     { 'ghp_test_token' }
  let(:filename)  { 'interviews.csv' }
  let(:csv_path)  { File.join(Dir.tmpdir, "gist_test_#{Process.pid}.csv") }
  let(:csv_content) { "company,job title\nAcme,Engineer\n" }
  let(:gist_url)  { 'https://gist.github.com/user/abc123' }

  before { File.write(csv_path, csv_content) }
  after  { FileUtils.rm_f(csv_path) }

  describe '#upload — create new gist (no gist_id)' do
    subject(:uploader) { described_class.new(token: token, filename: filename) }

    before do
      stub_request(:post, 'https://api.github.com/gists')
        .with(
          headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' },
          body:    hash_including(
            'description' => anything,
            'public'      => false,
            'files'       => { filename => { 'content' => csv_content } }
          )
        )
        .to_return(
          status: 201,
          body:   JSON.generate({ 'html_url' => gist_url, 'id' => 'abc123' }),
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'POSTs to /gists and returns the html_url' do
      expect(uploader.upload(csv_path)).to eq(gist_url)
    end

    it 'reads the file content and sends it in the request body' do
      uploader.upload(csv_path)
      expect(WebMock).to have_requested(:post, 'https://api.github.com/gists')
        .with(body: hash_including('files' => { filename => { 'content' => csv_content } }))
    end

    it 'creates a private (non-public) gist' do
      uploader.upload(csv_path)
      expect(WebMock).to have_requested(:post, 'https://api.github.com/gists')
        .with(body: hash_including('public' => false))
    end
  end

  describe '#upload — update existing gist (with gist_id)' do
    let(:gist_id) { 'abc123' }
    subject(:uploader) { described_class.new(token: token, gist_id: gist_id, filename: filename) }

    before do
      stub_request(:patch, "https://api.github.com/gists/#{gist_id}")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body:    hash_including('files' => { filename => { 'content' => csv_content } })
        )
        .to_return(
          status: 200,
          body:   JSON.generate({ 'html_url' => gist_url }),
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'PATCHes /gists/:id and returns the html_url' do
      expect(uploader.upload(csv_path)).to eq(gist_url)
    end

    it 'does not POST to /gists' do
      uploader.upload(csv_path)
      expect(WebMock).not_to have_requested(:post, 'https://api.github.com/gists')
    end
  end

  describe '#upload — API error' do
    subject(:uploader) { described_class.new(token: token, filename: filename) }

    before do
      stub_request(:post, 'https://api.github.com/gists')
        .to_return(status: 401, body: JSON.generate({ 'message' => 'Bad credentials' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'raises GistUploader::ApiError with the status and message' do
      expect { uploader.upload(csv_path) }
        .to raise_error(GistUploader::ApiError, /401.*Bad credentials/)
    end
  end

  describe '.from_env' do
    it 'builds an uploader from environment variables' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:fetch).with('GITHUB_TOKEN').and_return('env_token')
      allow(ENV).to receive(:[]).with('GIST_ID').and_return('env_gist_id')

      uploader = described_class.from_env(filename: filename)
      expect(uploader.instance_variable_get(:@token)).to eq('env_token')
      expect(uploader.instance_variable_get(:@gist_id)).to eq('env_gist_id')
    end

    it 'raises KeyError if GITHUB_TOKEN is not set' do
      allow(ENV).to receive(:fetch).with('GITHUB_TOKEN').and_raise(KeyError)
      expect { described_class.from_env(filename: filename) }.to raise_error(KeyError)
    end
  end
end
