class Thesis < ApplicationRecord
  has_many :chapters, -> { order(:order) }, dependent: :destroy
  has_many :extracted_facts, dependent: :destroy

  enum :status, {
    draft: 0,
    outline_submitted: 1,
    outline_approved: 2,
    research_in_progress: 3,
    research_done: 4,
    drafting: 5,
    verification: 6,
    complete: 7
  }

  def approve_outline!
    update!(status: :outline_approved) if outline_submitted?
  end

  def start_research!
    update!(status: :research_in_progress) if outline_approved?
  end

  def research_complete!
    update!(status: :research_done) if research_in_progress?
  end

  def start_drafting!
    update!(status: :drafting) if research_done?
  end

  def start_verification!
    update!(status: :verification) if drafting? && chapters.all?(&:draft_complete?)
  end

  def finalize!
    update!(status: :complete) if verification? && chapters.all?(&:verified?)
  end
end
