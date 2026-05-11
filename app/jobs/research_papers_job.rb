class ResearchPapersJob < ApplicationJob
  queue_as :default

  def perform(thesis_id)
    thesis = Thesis.find(thesis_id)

    # 1. Show loading spinner
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "research_section",
      partial: "theses/research_progress",
      locals: { thesis: thesis }
    )

    # 2. Fetch papers from Serper/Modal
    begin
      data = ModalApiClient.new.research(thesis.topic, thesis.target_paper_count || 15)
      papers_metadata = data["papers"] || []
    rescue => e
      Rails.logger.error "Modal Research Error: #{e.message}"
      papers_metadata = []
    end

    # 3. Create Paper records and collect abstracts for bulk extraction
    papers_map = {}
    abstracts = []

    papers_metadata.each do |p_attrs|
      paper = Paper.find_or_create_by!(doi: p_attrs["doi"]) do |p|
        p.title        = p_attrs["title"]
        p.url          = p_attrs["url"]
        p.citation_apa = p_attrs["citation_apa"]
        p.abstract     = p_attrs["abstract"]
      end

      # Map index to paper so we can link facts back correctly
      papers_map[abstracts.size] = paper
      abstracts << paper.abstract
    end

    # 4. BULK FACT EXTRACTION
    # We send ALL abstracts in one single call. The job blocks here until Modal returns everything.
    unless abstracts.empty?
      begin
        # This calls the /extract_facts endpoint in your main.py
        all_extracted_facts = ModalApiClient.new.extract_facts(abstracts)

        all_extracted_facts.each_with_index do |fact_list, index|
          target_paper = papers_map[index]

          fact_list.each do |fact_text|
            thesis.extracted_facts.create!(
              paper: target_paper,
              evidence_text: fact_text,
              confidence: 0.9,
              selected: true # Default to checked for user review
            )
          end
        end
      rescue => e
        Rails.logger.error "Bulk Fact Extraction Failed: #{e.message}"
        # Fallback: Create one fact from each abstract if bulk fails
        papers_map.each_value do |paper|
          thesis.extracted_facts.create!(paper: paper, evidence_text: paper.abstract.truncate(200), selected: true)
        end
      end
    end

    # 5. Finalize
    thesis.research_complete!
    thesis.reload

    # 6. Broadcast results to UI
    Turbo::StreamsChannel.broadcast_replace_to("thesis_#{thesis.id}", target: "research_section", partial: "theses/research_progress", locals: { thesis: thesis })
    Turbo::StreamsChannel.broadcast_replace_to("thesis_#{thesis.id}", target: "actions_section", partial: "theses/actions", locals: { thesis: thesis })
  end
end
