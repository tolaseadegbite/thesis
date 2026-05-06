class ResearchPapersJob < ApplicationJob
  queue_as :default

  def perform(thesis_id)
    thesis = Thesis.find(thesis_id)

    # 1. Immediate broadcast to show spinner
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "research_section",
      partial: "theses/research_progress",
      locals: { thesis: thesis }
    )

    sleep(5) # Simulate AI

    paper = Paper.create!(
      title: "Sample Academic Paper",
      url: "https://example.com",
      doi: "10.1234/example",
      citation_apa: "Doe, J. (2023). Sample Paper. Journal of Examples, 12(3), 45-67.",
      abstract: "This is a sample abstract."
    )

    thesis.extracted_facts.create!(
      paper: paper,
      evidence_text: "Microfinance increased yield by 14% in Oyo State.",
      page_number: 7,
      confidence: 0.9,
      selected: true # Default to true so they show up checked in the review
    )

    # 2. Update status and reload to ensure the view sees the change
    thesis.research_complete!
    thesis.reload

    # 3. Final broadcast to show the Fact Review table
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "research_section",
      partial: "theses/research_progress",
      locals: { thesis: thesis }
    )

    # Also update actions section to ensure everything is in sync
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "actions_section",
      partial: "theses/actions",
      locals: { thesis: thesis }
    )
  end
end
