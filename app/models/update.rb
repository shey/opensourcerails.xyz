# frozen_string_literal: true

# == Schema Information
#
# Table name: updates
#
#  id         :bigint           not null, primary key
#  date       :datetime
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Update < ApplicationRecord
  has_rich_text :content
end
