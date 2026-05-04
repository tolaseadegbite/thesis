class Paper < ApplicationRecord
  has_many :extracted_facts, dependent: :destroy
end
