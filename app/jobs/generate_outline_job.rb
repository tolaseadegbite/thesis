class GenerateOutlineJob < ApplicationJob
  queue_as :default

  def perform(thesis_id)
    thesis = Thesis.find(thesis_id)

    sleep(2)

    outline = {
      chapters: [
        { title: "Introduction", subsections: [ "Background", "Problem Statement", "Objectives" ] },
        { title: "Literature Review", subsections: [ "Theoretical Framework", "Empirical Studies" ] },
        { title: "Methodology", subsections: [ "Research Design", "Data Collection" ] },
        { title: "Discussion", subsections: [ "Analysis", "Findings" ] },
        { title: "Conclusion", subsections: [ "Summary", "Recommendations" ] }
      ]
    }

    thesis.transaction do
      thesis.update!(outline: outline, status: :outline_submitted)

      outline[:chapters].each_with_index do |chap, idx|
        thesis.chapters.create!(title: chap[:title], order: idx, status: :pending)
      end
    end

    # Broadcast updates
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
