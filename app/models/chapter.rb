class Chapter < ApplicationRecord
  belongs_to :thesis
  has_many :audit_logs, dependent: :destroy
  validates :title, presence: true

  enum :status, { pending: 0, drafting: 1, draft_complete: 2, verified: 3 }

  after_initialize :set_default_subsections, if: :new_record?

  def resolved_markdown
    return "" if markdown_content.blank?

    ordered_facts = thesis.extracted_facts.selected.order(:id).to_a

    # This Regex matches the [Fact ID: X] and any whitespace immediately preceding it
    markdown_content.gsub(/\s?\[Fact ID:\s*(\d+)\]/i) do |match|
      ai_index = $1.to_i
      fact = (ai_index > 0 && ai_index <= ordered_facts.size) ? ordered_facts[ai_index - 1] : thesis.extracted_facts.find_by(id: ai_index)

      if fact && fact.paper
        # We add one leading space here to keep the sentence flow clean
        " " + format_short_citation(fact.paper)
      else
        ""
      end
    end
  end

  def subsections_string
    subsections.join(", ")
  end

  def subsections_string=(val)
    self.subsections = val.split(",").map(&:strip).reject(&:blank?)
  end

  private

  def format_short_citation(paper)
    # 1. Year Extraction
    year_match = paper.citation_apa.match(/(19|20)\d{2}/)
    year = year_match ? year_match[0] : "n.d."

    # 2. Author/Title Extraction
    # Strip common academic prefixes
    clean_cit = paper.citation_apa.gsub(/^\(PDF\)\s*|^\[PDF\]\s*/i, "").strip

    author = if clean_cit.include?(",") && clean_cit.split(",").first.split(" ").size < 3
               # If it looks like "LastName, F.", take "LastName"
               clean_cit.split(",").first.gsub(/[^a-zA-Z\s]/, "").strip
    else
               # If it's a title, take only the first 3 words to keep it short
               clean_cit.split(" ").first(3).join(" ").gsub(/[^a-zA-Z\s]/, "")
    end

    "(#{author}, #{year})"
  end

  def set_default_subsections
    self.subsections ||=[]
  end
end
