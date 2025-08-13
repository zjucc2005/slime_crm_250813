# encoding: utf-8
class Hospital < ApplicationRecord
  has_many :departments, class_name: 'HospitalDepartment', dependent: :destroy
  validates_presence_of :name
  validates_uniqueness_of :name, case_sensitive: false
  before_validation :setup, on: [:create, :update]

  CATEGORY = %w[公立 私立]
  LEVEL = %w[三级 三甲 三乙 三丙 二级 二甲 二乙 二丙 一级 一甲 一乙 一丙]
  MAX_KWLIST_LENGTH = 5

  def self.level_sort(level)
    %w[一 二 三].include?(level[0]) ? "#{level[0]}级" : '未评级'
  end

  private
  def setup
    self.name = name.try(:strip)
    if kwlist.is_a? String
      self.kwlist = kwlist.split(',').map(&:strip)
      if self.kwlist.length > MAX_KWLIST_LENGTH
        errors.add(:kwlist, :less_than_or_equal_to, count: MAX_KWLIST_LENGTH)
      end
    elsif kwlist.is_a? Array
      self.kwlist = kwlist.map(&:to_s).map(&:strip)
    elsif kwlist.nil?
      self.kwlist = []
    else
      errors.add(:kwlist, :invalid_format)
    end
  end
end