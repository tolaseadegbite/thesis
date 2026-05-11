class GeneratePdfJob < ApplicationJob
  queue_as :default

  def perform(thesis_id)
    thesis = Thesis.find(thesis_id)
    thesis.pdf_generating!

    # 1. Immediate broadcast to show "Assembling Chapters..." spinner
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "actions_section",
      partial: "theses/actions",
      locals: { thesis: thesis }
    )

    # 2. Simulate PDF Generation Time
    # (Ferrum logic is currently handled in the controller's download_pdf action)
    sleep(4)

    # 3. Finalize state
    thesis.pdf_ready!

    # 4. Final broadcast to show the "Download PDF Now" button
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "actions_section",
      partial: "theses/actions",
      locals: { thesis: thesis }
    )
  end
end
