class SeoMetatagSerializer < ActiveModel::Serializer
  attributes :id, :page_type, :title, :description, :keywords_array, :image_url, 
             :canonical_url, :no_index, :language, :active, :seo_status, :seo_issues,
             :created_at, :updated_at

  def keywords_array
    object.keywords_array
  end

  def seo_status
    object.seo_status
  end

  def seo_issues
    object.seo_issues
  end
end 