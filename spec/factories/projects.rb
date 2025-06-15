# == Schema Information
#
# Table name: projects
#
#  id                   :bigint           not null, primary key
#  branch               :string
#  color                :string
#  contributors         :integer          default(1), not null
#  data                 :json             not null
#  dependents           :integer
#  description          :string
#  forks                :integer          default(0), not null
#  github               :string           not null
#  github_about         :text
#  hidden_at            :datetime
#  last_activity_at     :datetime
#  last_commit          :string
#  meta_last_updated_at :datetime
#  name                 :string           not null
#  pulse                :integer
#  rails_major_version  :integer          not null
#  readme               :text
#  short_blurb          :text
#  slug                 :string           not null
#  stars                :integer          default(0), not null
#  watchers             :integer          default(1), not null
#  website              :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_projects_on_hidden_at  (hidden_at)
#  index_projects_on_slug       (slug) UNIQUE
#
FactoryBot.define do
  factory :project do
    name { "GitLab" }
    slug { "gitlab" }
    github { "gitlabhq/gitlabhq" }
    rails_major_version { 5 }
  end
end
