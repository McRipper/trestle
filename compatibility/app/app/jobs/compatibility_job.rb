class CompatibilityJob < ActiveJob::Base
  def perform(article_id)
    Article.find(article_id).update!(body_en: 'Performed by GoodJob')
  end
end
