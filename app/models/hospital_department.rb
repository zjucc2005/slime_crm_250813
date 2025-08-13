# encoding: utf-8
class HospitalDepartment < ApplicationRecord
  belongs_to :hospital, :class_name => 'Hospital'
  validates_presence_of :name
  before_validation :setup, on: [:create, :update]

  def can_delete?
    CandidateExperience.hospital.where(dep_id: id).count.zero?
  end

  private

  def setup
    self.name = name.try(:strip)
    if hospital.departments.where.not(id: id).exists?(name: name)
      errors.add(:name, :taken)
    end
  end
end