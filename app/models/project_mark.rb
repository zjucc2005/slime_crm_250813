class ProjectMark < ApplicationRecord
  TYPE = {
    top: '置顶',
    hold: '挂起'
  }.stringify_keys

  belongs_to :user
  belongs_to :project

  # 验证组合唯一性
  validates :user_id, uniqueness: { scope: :project_id }
  validates_inclusion_of :mark_type, in: TYPE.keys
end
