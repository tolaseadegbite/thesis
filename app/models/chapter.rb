class Chapter < ApplicationRecord
  belongs_to :thesis
  has_many :audit_logs, dependent: :destroy

  enum :status, {
    pending: 0,
    drafting: 1,
    draft_complete: 2,
    verified: 3
  }
end
