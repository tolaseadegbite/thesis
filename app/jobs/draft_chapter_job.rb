class DraftChapterJob < ApplicationJob
  queue_as :default

  def perform(chapter_id)
    chapter = Chapter.find(chapter_id)
    thesis = chapter.thesis
    thesis.start_drafting! if thesis.research_done?

    chapter.update!(status: :drafting)

    sleep(3)  # placeholder AI
    facts = thesis.extracted_facts.first(5)
    content = "# #{chapter.title}\n\n"
    facts.each do |fact|
      content += "According to a study, #{fact.evidence_text} [Fact ID: #{fact.id}]\n\n"
    end

    chapter.update!(markdown_content: content, status: :draft_complete)

    # Broadcast the updated chapter
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "chapter_#{chapter.id}",
      partial: "chapters/chapter",
      locals: { chapter: chapter }
    )

    # If the thesis is in verification, automatically start verifying this chapter again
    if thesis.verification?
      VerifyChapterJob.perform_later(chapter.id)
    end

    # Update actions if all chapters are now draft_complete (only matters when not in verification)
    if thesis.chapters.all?(&:draft_complete?) && thesis.drafting?
      Turbo::StreamsChannel.broadcast_replace_to(
        "thesis_#{thesis.id}",
        target: "actions_section",
        partial: "theses/actions",
        locals: { thesis: thesis }
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "chapter_progress",
      partial: "theses/chapter_progress",
      locals: { thesis: thesis }
    )
  end
end
