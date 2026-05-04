class AuditLog < ApplicationRecord
  belongs_to :chapter
  belongs_to :fact, class_name: "ExtractedFact", optional: true
end
