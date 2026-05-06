class Chapter < ApplicationRecord
  belongs_to :thesis
  has_many :audit_logs, dependent: :destroy
  validates :title, presence: true

  enum :status, { pending: 0, drafting: 1, draft_complete: 2, verified: 3 }

  after_initialize :set_default_subsections, if: :new_record?

  def subsections_string
    subsections.join(", ")
  end

  def subsections_string=(val)
    self.subsections = val.split(",").map(&:strip).reject(&:blank?)
  end

  private

  def set_default_subsections
    self.subsections ||= []
  end
end
