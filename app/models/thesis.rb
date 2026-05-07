class Thesis < ApplicationRecord
  has_many :chapters, -> { order(:order) }, dependent: :destroy
  has_many :extracted_facts, dependent: :destroy
  accepts_nested_attributes_for :chapters, allow_destroy: true, reject_if: :all_blank

  # Only sync JSON outline once the entire transaction is finished
  after_commit :sync_outline_cache, on: [ :create, :update ], if: -> { chapters.any? }

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

  # --- PRICING CONSTANTS ---
  COST_PER_PAPER = 0.01
  COST_PER_CHAPTER = 0.02

  def calculate_cost_estimate
    # Reject chapters marked for deletion in the current memory state
    active_chapters = chapters.reject(&:marked_for_destruction?).size
    papers = target_paper_count || 15
    ((active_chapters * COST_PER_CHAPTER) + (papers * COST_PER_PAPER)).round(2)
  end

  def sync_outline_cache
    # Use update_column to avoid triggering another commit cycle
    new_outline_data = chapters.order(:order).map do |ch|
      { "title" => ch.title, "subsections" => ch.subsections || [] }
    end
    update_column(:outline, { "chapters" => new_outline_data })
  end

  # State Machine methods
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

  def start_verification!(depth = nil)
    return unless drafting? && chapters.all?(&:draft_complete?)

    # Update both status and depth in a single database call
    attrs = { status: :verification }
    attrs[:verification_depth] = depth if depth.present?
    update!(attrs)
  end

  def finalize!
    update!(status: :complete) if verification? && chapters.all?(&:verified?)
  end
end
