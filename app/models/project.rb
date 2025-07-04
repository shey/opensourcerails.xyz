# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id                        :bigint           not null, primary key
#  branch                    :string
#  color                     :string
#  contributors              :integer          default(1), not null
#  data                      :json             not null
#  dependents                :integer
#  description               :string
#  forks                     :integer          default(0), not null
#  github                    :string           not null
#  github_about              :text
#  hidden_at                 :datetime
#  last_activity_at          :datetime
#  last_commit               :string
#  meta_last_updated_at      :datetime
#  name                      :string           not null
#  performance_dashboard_url :string
#  pulse                     :integer
#  rails_major_version       :integer          not null
#  readme                    :text
#  short_blurb               :text
#  slug                      :string           not null
#  stars                     :integer          default(0), not null
#  watchers                  :integer          default(1), not null
#  website                   :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_projects_on_created_at_desc_for_feed  (created_at DESC,hidden_at,last_activity_at)
#  index_projects_on_hidden_at                 (hidden_at)
#  index_projects_on_slug                      (slug) UNIQUE
#
class Project < ApplicationRecord
  class MissingGems < RuntimeError; end

  class MissingBranch < RuntimeError; end

  class Helpers
    def initialize(project)
      @project = project
    end

    def scrape_last_activity
      Projects::GithubActivityScraper.new(@project)
    end

    def scrape_last_activity!
      result = scrape_last_activity
      result.run
      @project.update!(last_activity_at: result.last_activity_at, last_commit: result.last_commit) if result
    end

    def scrape_meta
      Projects::GithubMetaScraper.new(@project)
    end

    def scrape_meta!(first = false)
      result = scrape_meta
      result.run
      if result
        @project.assign_attributes(
          branch: result.branch,
          stars: result.stars,
          forks: result.forks,
          github_about: result.about,
          license_list: result.license,
          meta_last_updated_at: Time.current,
          watchers: result.watchers,
          github: result.repo
        )
        @project.name = result.name if (result.name.present? && @project.name.nil?) || first
        @project.website = result.website if (result.website.present? && @project.website.nil?) || first
        @project.save!
      end
    end

    def scrape_app
      raise MissingBranch, "requires branch. Please run #scrape_meta! first." if @project.branch.nil?

      Projects::GithubAppScraper.new(@project)
    end

    def scrape_app!
      result = scrape_app
      result.run
      @project.update!(app_directory_list: result.app) if result
    end

    def scrape_readme
      raise MissingBranch, "requires branch. Please run #scrape_meta! first." if @project.branch.nil?

      Projects::GithubReadmeScraper.new(@project)
    end

    def scrape_readme!
      result = scrape_readme
      result.run
      @project.update!(readme: result.content) if result
    end

    def scrape_gemfile
      raise MissingBranch, "requires branch. Please run #scrape_meta! first." if @project.branch.nil?

      Projects::GemfileScraper.new(@project)
    end

    def scrape_gemfile!
      result = scrape_gemfile
      result.run
      @project.update!(gem_list: result.gems) if result
    end

    def scrape_packages
      raise MissingBranch, "requires branch. Please run #scrape_meta! first." if @project.branch.nil?

      Projects::PackageScraper.new(@project)
    end

    def scrape_packages!
      result = scrape_packages
      result.run
      @project.update!(package_list: result.packages) if result
    end

    def analyze_stacks
      raise MissingGems, "requires gems. Please run #scrape_gemfile! first." if @project.gems.empty?

      Projects::StackAnalyzer.new(@project)
    end

    def analyze_stacks!
      result = analyze_stacks
      result.run
      return :nope unless result

      @project.assign_attributes(frontend_stack_list: result.frontend) if result.frontend
      @project.assign_attributes(backend_stack_list: result.backend) if result.backend
      @project.save!
    end

    # this isn't used yet
    def check_pulse
      raise MissingGems, "requires gems. Please run #scrape_gemfile! first." if @project.gems.empty?

      Projects::PulseCalculator.new(@project)
    end

    # this isn't used yet
    def check_pulse!
      result = check_pulse
      result.run
      @project.update!(pulse: result.pulse) if result
    end

    def scan!(first = false)
      scrape_meta!(first)
      scrape_last_activity!
      scrape_app!
      scrape_gemfile!
      scrape_packages!
      analyze_stacks!
      check_pulse!
    end

    def sync!
      scrape_last_activity!
    end

    def weekly_sync!
      scrape_app!
      scrape_gemfile!
      scrape_packages!
      analyze_stacks!
      check_pulse!
    end
  end

  extend FriendlyId
  include AttrJson::Record

  attr_json_config default_container_attribute: :data
  attr_json :gems_path, :string
  attr_json :packages_path, :string

  friendly_id :name, use: [:slugged, :history]
  has_rich_text :content
  has_one_attached :primary_image

  acts_as_taggable_on :categories
  acts_as_taggable_on :license
  acts_as_taggable_on :adjectives
  acts_as_taggable_on :gems
  acts_as_taggable_on :packages
  acts_as_taggable_on :app_directories
  acts_as_taggable_on :backend_stack
  acts_as_taggable_on :frontend_stack

  validates :slug, uniqueness: true
  validate :license_count
  validates :performance_dashboard_url,
    format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    allow_blank: true

  scope :without_tagged, lambda { |context|
                           where.not(id: ActsAsTaggableOn::Tagging.distinct(:taggable_id).select(:taggable_id).where(context: context))
                         }

  tag_types.each do |type|
    scope :"without_tagged_#{type}", -> { without_tagged(type) }
  end

  scope :slim, -> {
    select(:id, :slug, :name, :description, :short_blurb, :color, :updated_at)
      .includes(:adjectives)
      .with_attached_primary_image
  }

  scope :hidden, -> {
    where.not(hidden_at: nil)
  }

  scope :visible, -> {
    where(hidden_at: nil).where.not(last_activity_at: nil)
  }

  scope :latest, ->(limit = 15) {
    visible.order(created_at: :desc).limit(limit)
  }

  attribute :skip_scan, :boolean, default: false

  after_create_commit :scan_project_first!, unless: :skip_scan?

  def user
    @user ||= github.split("/")[0]
  end

  def repo
    @repo ||= github.split("/")[1]
  end

  def helpers
    Helpers.new(self)
  end

  def summary_for_feed
    short_blurb.presence ||
      description.presence ||
      "An open-source Ruby on Rails project on GitHub: #{github}"
  end

  private

  def license_count
    if license_ids.size > 1
      errors.add(:license, "should only have one.")
      throw(:abort)
    end
  end

  def scan_project_first!
    Projects::ScanProjectWorker.perform_async(slug, true)
  end

  def scan_project!
    Projects::ScanProjectWorker.perform_async(slug)
  end
end
