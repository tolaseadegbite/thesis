# app/jobs/draft_chapter_job.rb
class DraftChapterJob < ApplicationJob
  queue_as :default

  def perform(chapter_id)
    chapter = Chapter.find(chapter_id)
    thesis = chapter.thesis

    thesis.start_drafting! if thesis.research_done?

    # --- 1. INITIALIZE HEARTBEAT ---
    # Check if this is a first draft or a correction based on the AuditLog
    latest_rejection = chapter.audit_logs.where(action: "verify_reject").last
    is_correction = latest_rejection.present?

    if is_correction
      update_heartbeat(chapter, "Reading Professor's feedback...")
      sleep(1)
      update_heartbeat(chapter, "Re-evaluating Fact IDs against the critique...")
      sleep(2)
      update_heartbeat(chapter, "Re-writing paragraph to address hallucinations...")
      sleep(2)
    else
      # Standard First Draft Loop
      update_heartbeat(chapter, "Initializing AI Drafter...")
      sleep(1)

      subsections = chapter.subsections ||[]
      if subsections.any?
        subsections.each_with_index do |sub, index|
          update_heartbeat(chapter, "Writing section #{index + 1}/#{subsections.size}: #{sub}...")
          sleep(2)
        end
      else
        update_heartbeat(chapter, "Synthesizing research facts...")
        sleep(3)
      end
    end

    # --- 3. FINALIZING ---
    update_heartbeat(chapter, "Formatting citations and reviewing tone...")
    sleep(1)

    # --- GENERATE CONTENT ---
    if is_correction
      # Simulate fixing the document
      content = chapter.markdown_content + "\n\n> **[AI Correction Applied]**: Fixed hallucination regarding statistic. Updated to reflect correct finding based on Professor's notes: *\"#{latest_rejection.professor_notes}\"*."
    else
      # Standard initial generation
      facts = thesis.extracted_facts.selected.order(:id).first(5)
      content = "# #{chapter.title}\n\n"
      facts.each do |fact|
        content += "According to #{fact.paper.citation_apa}, #{fact.evidence_text}[Fact ID: #{fact.id}]\n\n"
      end
    end

    # --- 4. SAVE COMPLETE CONTENT & CLEAR HEARTBEAT ---
    chapter.update!(markdown_content: content, status: :draft_complete, status_message: nil)

    broadcast_chapter(chapter)

    # If the thesis is in verification, it must go back to the Professor to check the fix
    if thesis.verification?
      VerifyChapterJob.perform_later(chapter.id)
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "chapter_progress",
      partial: "theses/chapter_progress",
      locals: { thesis: thesis }
    )

    if thesis.chapters.all?(&:draft_complete?) && thesis.drafting?
      Turbo::StreamsChannel.broadcast_replace_to(
        "thesis_#{thesis.id}",
        target: "actions_section",
        partial: "theses/actions",
        locals: { thesis: thesis }
      )
    end
  end

  private

  def update_heartbeat(chapter, message)
    chapter.update!(status: :drafting, status_message: message)
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
end
