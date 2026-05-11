class DraftChapterJob < ApplicationJob
  queue_as :default

  # Limit to 3 to match Modal's max_containers=3 for the L40S Drafter
  limits_concurrency to: 3, key: "drafter_gpu_queue"

  def perform(chapter_id)
    chapter = Chapter.find(chapter_id)
    thesis  = chapter.thesis

    # Trigger macro status change
    thesis.start_drafting! if thesis.research_done?

    # --- 1. INITIALIZE HEARTBEAT ---
    latest_rejection = chapter.audit_logs.where(action: "verify_reject").last
    is_correction = latest_rejection.present?

    if is_correction
      update_heartbeat(chapter, "Applying corrections based on Professor feedback...")
    else
      update_heartbeat(chapter, "Initializing AI Drafter for #{chapter.subsections.size} subsections...")
    end

    # --- 2. GATHER FACTS ---
    # Only send evidence approved by the user in Step #2
    facts = thesis.extracted_facts.selected.pluck(:evidence_text)

    # --- 3. CALL MODAL GPU ---
    begin
      # If it's a correction, we send the previous content and the notes to the model
      response = ModalApiClient.new.draft_chapter(
        title:            chapter.title,
        subsections:      chapter.subsections || [],
        facts:            facts,
        previous_draft:   is_correction ? chapter.markdown_content : nil,
        correction_notes: is_correction ? latest_rejection.professor_notes : nil
      )
      content = response["content"]
    rescue => e
      update_heartbeat(chapter, "Connection error. Retrying draft...")
      raise e # Solid Queue will retry automatically
    end

    # --- 4. FINALIZE & CLEAR HEARTBEAT ---
    chapter.update!(
      markdown_content: content,
      status: :draft_complete,
      status_message: nil # Remove heartbeat text on completion
    )

    # Broadcast updated chapter (now showing markdown)
    broadcast_chapter(chapter)

    # --- 5. THE DEBATE LOOP ---
    # If the thesis is already in verification mode, immediately ask the professor to check the fix
    if thesis.verification?
      VerifyChapterJob.perform_later(chapter.id)
    end

    # --- 6. UPDATE GLOBAL PROGRESS ---
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "chapter_progress",
      partial: "theses/chapter_progress",
      locals: { thesis: thesis }
    )

    # If all chapters are done, show the "Start Verification" button
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
    # update_columns bypasses model callbacks to prevent infinite loops with the Thesis outline cache
    chapter.update_columns(status: 1, status_message: message)
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
