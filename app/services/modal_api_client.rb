require "net/http"
require "uri"
require "json"

class ModalApiClient
  class RequestError < StandardError; end

  def initialize
    @config = Rails.application.credentials.modal
    @base_url = @config[:api_url].chomp("/")
  end

  # ── Thesis Methods ─────────────────────────────────────────

  def generate_outline(topic)
    post_json("/outline", { topic: topic })
  end

  def research(topic, paper_count = 15)
    post_json("/research", { topic: topic, paper_count: paper_count })
  end

  def extract_facts(abstracts)
    post_json("/extract_facts", { abstracts: abstracts })
  end

  def draft_chapter(title:, subsections:, facts:, previous_draft: nil, correction_notes: nil)
    post_json("/draft", {
      chapter_title: title,
      subsections: subsections,
      facts: facts,
      previous_draft: previous_draft,
      correction_notes: correction_notes
    })
  end

  def verify_chapter(draft:, facts:)
    post_json("/verify", { draft: draft, facts: facts })
  end

  private

  def post_json(path, body_hash)
    uri = URI.parse("#{@base_url}#{path}")
    http = setup_http(uri)

    request = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
    request.body = body_hash.to_json

    response = http.request(request)

    # Handle empty responses (cold‑start / container not ready)
    raise RequestError, "Modal #{path} returned empty response" if response.body.to_s.strip.empty?

    raise RequestError, "Modal #{path} failed: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def setup_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    http.open_timeout = 60
    http.read_timeout = 600
    http
  end
end
