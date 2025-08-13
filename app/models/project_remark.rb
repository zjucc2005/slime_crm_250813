class ProjectRemark < ApplicationRecord
  belongs_to :project
  
  validates :project_id, presence: true
  validates :remark, presence: true, allow_blank: true
end