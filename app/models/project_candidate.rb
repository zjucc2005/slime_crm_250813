# encoding: utf-8
class ProjectCandidate < ApplicationRecord
  # ENUM
  CATEGORY = { :expert => '专家', :client => '客户' }.stringify_keys
  MARK = {
    :declined    => '拒绝',
    :unsuitable  => '不合适',
    :recommended => '已推荐',
    :interviewed => '已访谈',
    :contacting  => '联络中',
    :pending     => '待定'
  }.stringify_keys
  CLIENT_MARK = { main: '主联系人', normal: '联系人' }.stringify_keys

  # Associations
  belongs_to :project, :class_name => 'Project'
  belongs_to :candidate, :class_name => 'Candidate'

  # Validations
  validates_inclusion_of :category, :in => CATEGORY.keys
  before_validation :setup, :on => :create

  # Scopes
  scope :expert, -> { where(category: 'expert') }
  scope :client, -> { where(category: 'client') }

  after_save do
    project.last_update
  end

  after_destroy do
    project.last_update
  end

  def update_mark_by_call_record_status(status)
    new_mark = {
      'pending'  => 'pending',
      'missed'   => 'contacting',
      'accepted' => 'recommended',
      'declined' => 'declined'
    }[status] || 'pending'
    self.update(mark: new_mark)
  end

  private
  def setup
    self.category ||= 'client'
    case category
    when 'expert' then self.mark ||= 'pending'
    when 'client' then self.mark ||= 'normal'
    end
  end

end
