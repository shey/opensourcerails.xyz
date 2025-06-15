# == Schema Information
#
# Table name: tags
#
#  id                     :integer          not null, primary key
#  data                   :jsonb            not null
#  name                   :string
#  slug                   :string           not null
#  taggings_count         :integer          default(0)
#  visible_taggings_count :integer          default(0), not null
#  created_at             :datetime
#  updated_at             :datetime
#
# Indexes
#
#  index_tags_on_data  (data) USING gin
#  index_tags_on_name  (name) UNIQUE
#  index_tags_on_slug  (slug) UNIQUE
#
class Tag < ActsAsTaggableOn::Tag
end
