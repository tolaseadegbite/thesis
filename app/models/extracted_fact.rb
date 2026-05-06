class ExtractedFact < ApplicationRecord
  belongs_to :thesis
  belongs_to :paper

  scope :selected, -> { where(selected: true) }
end
