# app/jobs/generate_outline_job.rb
class GenerateOutlineJob < ApplicationJob
  queue_as :default

  def perform(thesis_id)
    thesis = Thesis.find(thesis_id)

    # 1. Call Modal Outline Agent
    data = ModalApiClient.new.generate_outline(thesis.topic)

    # data looks like:
    # { "chapters" => [{ "title" => …, "subsections" => […] }, …], "paper_count" => 15, "cost_estimate" => "~$0.22" }

    outline = data.with_indifferent_access   # easier to use symbols
    chapters_array = outline[:chapters] || []
    paper_count = outline[:paper_count] || 15
    cost_est    = outline[:cost_estimate]

    # 2. Save to database inside a transaction
    thesis.transaction do
      thesis.update!(
        outline: { "chapters" => chapters_array },
        status: :outline_submitted,
        cost_estimate: cost_est,
        target_paper_count: paper_count
      )

      # Create Chapter records with subsections
      chapters_array.each_with_index do |chap, idx|
        thesis.chapters.create!(
          title: chap[:title],
          order: idx,
          status: :pending,
          subsections: chap[:subsections] || []
        )
      end
    end

    # 3. Broadcast updates (same as before)
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "outline_section",
      partial: "theses/outline",
      locals: { thesis: thesis }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "actions_section",
      partial: "theses/actions",
      locals: { thesis: thesis }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "thesis_status",
      partial: "theses/status",
      locals: { thesis: thesis }
    )
  end
end
