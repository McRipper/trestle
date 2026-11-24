Trestle.resource(:articles) do
  menu { item :articles }

  search do |query|
    query.present? ? collection.where("title ->> 'en' ILIKE ?", "%#{query}%") : collection
  end

  active_storage_fields { [:cover, :documents] }

  table do
    column :id
    column :title
    actions
  end

  form do |article|
    mobility_text_field :title
    mobility_text_area :body
    mobility_check_box :published
    editor :rich_text
    tinymce :summary, data: { tinymce_configuration_value: 'summary' }
    active_storage_field :cover
    active_storage_field :documents
  end
end
