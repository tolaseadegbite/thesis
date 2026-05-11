class VerifyChapterJob < ApplicationJob
  queue_as :default

  # Run only one verification at a time to match the A100's max_containers=1
  limits_concurrency to: 1, key: "professor_gpu_queue"

  # Retry automatically when the A100 is still booting (cold‑start)
  retry_on ModalApiClient::RequestError, wait: 15.seconds, attempts: 5

  def perform(chapter_id)
    chapter = Chapter.find(chapter_id)
    thesis  = chapter.thesis

    update_progress(chapter, "Waking up Professor (A100 GPU)... This usually takes 2-3 minutes on the first run.")

    facts = thesis.extracted_facts.selected.pluck(:evidence_text)
    update_progress(chapter, "Checking claims against #{facts.size} facts...")

    result = ModalApiClient.new.verify_chapter(
      draft: chapter.markdown_content,
      facts: facts
    )

    if result["passed"]
      chapter.update!(status: :verified, status_message: nil)
      AuditLog.create!(chapter: chapter, action: "verify_pass", professor_notes: "Factual alignment confirmed.")

      # ---------- ADDED: Live progress update ----------
      broadcast_chapter(chapter)
      broadcast_chapter_progress(thesis)
      # -------------------------------------------------

    else
      correction = result["corrections"]&.first
      reason = correction ? correction["reason"] : "Factual inconsistency detected."

      AuditLog.create!(
        chapter: chapter,
        action: "verify_reject",
        old_text: chapter.markdown_content,
        new_text: "(awaiting re‑draft)",
        professor_notes: reason
      )

      DraftChapterJob.perform_later(chapter.id)
      return
    end

    check_thesis_completion(thesis)
  end

  private

  def update_progress(chapter, message)
    chapter.update_columns(status_message: message)
    broadcast_chapter(chapter)
  end

  def broadcast_chapter(chapter)
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{chapter.thesis_id}",
      target: "chapter_#{chapter.id}",
      partial: "chapters/chapter",
      locals: { chapter: chapter }
    )
  end

  # ---------- ADDED: Live progress bar update ----------
  def broadcast_chapter_progress(thesis)
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "chapter_progress",
      partial: "theses/chapter_progress",
      locals: { thesis: thesis }
    )
  end

  def check_thesis_completion(thesis)
    thesis.reload
    if thesis.chapters.all?(&:verified?) && !thesis.complete?
      thesis.finalize!
      # Sync UI states
      %w[thesis_status actions_section chapter_progress].each do |target|
        partial = target == "thesis_status" ? "status" : target
        Turbo::StreamsChannel.broadcast_replace_to(
          "thesis_#{thesis.id}",
          target: target,
          partial: "theses/#{partial}",
          locals: { thesis: thesis }
        )
      end
    end
  end
end
