class DraftChapterJob < ApplicationJob
  queue_as :default

  def perform(chapter_id)
    chapter = Chapter.find(chapter_id)
    thesis = chapter.thesis

    # Trigger macro status if it hasn't been triggered yet
    thesis.start_drafting! if thesis.research_done?

    # --- 1. INITIALIZE HEARTBEAT ---
    update_heartbeat(chapter, "Initializing AI Drafter...")
    sleep(1)

    # --- 2. SUBSECTION DRAFTING LOOP ---
    subsections = chapter.subsections ||[]
    if subsections.any?
      subsections.each_with_index do |sub, index|
        update_heartbeat(chapter, "Writing section #{index + 1}/#{subsections.size}: #{sub}...")
        sleep(2) # Simulate GPU processing time for each specific subsection
      end
    else
      update_heartbeat(chapter, "Synthesizing research facts...")
      sleep(3)
    end

    # --- 3. FINALIZING ---
    update_heartbeat(chapter, "Formatting citations and reviewing tone...")
    sleep(1)

    # Generate dummy content
    facts = thesis.extracted_facts.selected.order(:id).first(5)
    content = "# #{chapter.title}\n\n"
    facts.each do |fact|
      content += "According to #{fact.paper.citation_apa}, #{fact.evidence_text} [Fact ID: #{fact.id}]\n\n"
    end

    # --- 4. SAVE COMPLETE CONTENT & CLEAR HEARTBEAT ---
    chapter.update!(markdown_content: content, status: :draft_complete, status_message: nil)

    # Broadcast the finalized chapter card
    broadcast_chapter(chapter)

    # Check for Verification loop (if redrafting after a failure)
    if thesis.verification?
      VerifyChapterJob.perform_later(chapter.id)
    end

    # Update Global Progress Bar
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "chapter_progress",
      partial: "theses/chapter_progress",
      locals: { thesis: thesis }
    )

    # If this was the last chapter to finish, reveal the "Start Verification" button
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

  # Helper method to save the status and instantly broadcast it
  def update_heartbeat(chapter, message)
    chapter.update!(status: :drafting, status_message: message)
    broadcast_chapter(chapter)
  end

  # Helper method to dry up the Turbo Stream call
  def broadcast_chapter(chapter)
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{chapter.thesis_id}",
      target: "chapter_#{chapter.id}",
      partial: "chapters/chapter",
      locals: { chapter: chapter }
    )
  end
end
