# frozen_string_literal: true

class ProjectDecorator < ApplicationDecorator
  delegate_all

  # used for background colors on a projects list
  def extracted_colors
    Miro::DominantColors.new(Rails.application.routes.url_helpers.rails_storage_proxy_path(primary_image.blob)).to_hex
  end
end
