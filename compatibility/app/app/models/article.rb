class Article < ApplicationRecord
  extend Mobility
  translates :title, :body, :published, backend: :jsonb
  has_one_attached :cover
  has_many_attached :documents
end
