class Article < ApplicationRecord
  extend Mobility
  translates :title, :body, :published, backend: :jsonb
  validates :title_en, presence: true
  has_one_attached :cover
  has_many_attached :documents
end
