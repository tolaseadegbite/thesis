# app/models/chapter.rb
class Chapter < ApplicationRecord
  belongs_to :thesis
  has_many :audit_logs, dependent: :destroy
  validates :title, presence: true

  enum :status, {
    pending: 0,
    drafting: 1,
    draft_complete: 2,
    verified: 3
  }

  after_initialize :set_default_subsections, if: :new_record?

  # Virtual attribute to power the text area in the form
  def subsections_string
    subsections.join(", ")
  end

  def subsections_string=(val)
    # Splits by comma, strips whitespace, and removes empty strings
    self.subsections = val.split(",").map(&:strip).reject(&:blank?)
  end

  private

  def set_default_subsections
    self.subsections ||=[]
  end
end
