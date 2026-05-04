class VerifyChapterJob < ApplicationJob
  queue_as :default

  def perform(chapter_id)
    chapter = Chapter.find(chapter_id)
    thesis = chapter.thesis
    thesis.start_verification! if thesis.drafting?

    sleep(2)  # placeholder AI verification
    passed = [ true, false ].sample

    if passed
      chapter.update!(status: :verified)
      AuditLog.create!(
        chapter: chapter,
        action: "verify_pass",
        professor_notes: "All facts matched source materials."
      )

      # Immediately show this chapter as verified in the UI
      Turbo::StreamsChannel.broadcast_replace_to(
        "thesis_#{thesis.id}",
        target: "chapter_#{chapter.id}",
        partial: "chapters/chapter",
        locals: { chapter: chapter }
      )

      # Update the overall chapter progress bar (X / Y verified)
      Turbo::StreamsChannel.broadcast_replace_to(
        "thesis_#{thesis.id}",
        target: "chapter_progress",
        partial: "theses/chapter_progress",
        locals: { thesis: thesis }
      )
    else
      AuditLog.create!(
        chapter: chapter,
        action: "verify_reject",
        old_text: chapter.markdown_content,
        new_text: "(awaiting re‑draft)",
        professor_notes: "Exaggerated statistic in paragraph 2. Expected ~14%, found 40%."
      )
      DraftChapterJob.perform_later(chapter.id)
      return
    end

    # Only broadcast thesis completion once
    thesis.reload
    if thesis.chapters.all?(&:verified?) && thesis.status != "complete"
      thesis.finalize!
      Turbo::StreamsChannel.broadcast_replace_to(
        "thesis_#{thesis.id}",
        target: "thesis_status",
        partial: "theses/status",
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
        target: "chapter_progress",
        partial: "theses/chapter_progress",
        locals: { thesis: thesis }
      )
    end
  end
end
