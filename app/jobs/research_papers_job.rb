class ResearchPapersJob < ApplicationJob
  queue_as :default

  def perform(thesis_id)
    thesis = Thesis.find(thesis_id)

    # Immediately show the loading state (in case the redirect hasn't finished)
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "research_section",
      partial: "theses/research_progress",
      locals: { thesis: thesis }
    )

    sleep(5)  # placeholder AI research

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
      confidence: 0.9
    )

    thesis.research_complete!  # sets status to research_done

    # Broadcast the completed state
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "research_section",
      partial: "theses/research_progress",
      locals: { thesis: thesis }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "actions_section",
      partial: "theses/actions",
      locals: { thesis: thesis }
    )
  end
end
