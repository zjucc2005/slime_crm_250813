# encoding: utf-8
module Utils
  class HaodfTemplateParser
    # 解析Haodf医生数据导入模板
    # 策略: 1 - 导入时仅回滚报错条目, 2 - 重复导入更新相关信息

    attr_accessor :errors, :row, :created_by, :user_channel_id, :candidate_attr, :work_exp_attrs

    def initialize(row, created_by=nil, user_channel_id=nil)
      @row = row.map(&method(:cell_strip))
      @errors = []
      @created_by = created_by
      @user_channel_id = user_channel_id
      @haodf_id = nil
      @candidate_attr = {}
      @work_exp_attrs = []
      @hospital_attr  = {}
      set_candidate_attr
    end

    # 返回值 true/false
    def import
      if valid?
        # import code
        begin
          ActiveRecord::Base.transaction do
            candidate = Candidate.doctor.where("CAST(property->>'haodf_id' AS BIGINT) = ?", @haodf_id).first
            if candidate
              candidate.update!(
                expertise: @candidate_attr[:expertise],
                inquiry:   @candidate_attr[:inquiry]
              )
              if @work_exp_attrs.present?
                work_exp = candidate.experiences.hospital.first
                work_exp ?
                  work_exp.update!(@work_exp_attrs[0]) :
                  candidate.experiences.hospital.create!(@work_exp_attrs[0])
              end
            else
              candidate = Candidate.doctor.create!(@candidate_attr)
              candidate.experiences.hospital.create!(@work_exp_attrs[0]) if @work_exp_attrs.present?
            end
          end
          true  # return
        rescue Exception => e
          @errors << e.message
          false # return
        end
      else
        false # return
      end
    end

    # 返回值 true/false
    def valid?
      @errors.empty?
    end

    private
    def cell_strip(cell)
      String === cell ? cell.strip : cell
    end

    def set_candidate_attr
      @haodf_id     = @row[0].to_i
      province      = @row[1]
      city          = @row[2]
      hospital      = @row[3]
      level         = @row[4]
      department    = @row[5]
      name          = @row[6]
      haodf_url     = @row[7]
      title         = @row[8]
      expertise     = @row[9]
      inquiry       = @row[10].to_i

      # default setting
      cpt           = 0
      currency      = 'RMB'

      @errors << '姓名不能为空, name is required' if name.blank?
      first_name, last_name = Candidate.name_split(name)

      province_obj = LocationDatum.provinces.where('name LIKE ?', "#{province}%").first
      if LocationDatum::DIRECT_CODE.include?(province_obj.code) # 直辖市/港澳
        city_obj = province_obj.children.first.children.where('name LIKE ?', "#{city}%").first
      else
        city_obj = province_obj.children.where('name LIKE ?', "#{city}%").first
      end
      city_name = city_obj ? city_obj.name : city  # 部分地区名,
      @hospital_attr = {
          name: hospital, province: province_obj.name, city: city_name, level: level, department: department
      }
      @hospital = Hospital.where(name: @hospital_attr[:name], province: @hospital_attr[:province], city: @hospital_attr[:city]).first
      @hospital ||= Hospital.create!(name: @hospital_attr[:name], province: @hospital_attr[:province], city: @hospital_attr[:city], level: @hospital_attr[:level])
      @department = @hospital.departments.find_or_create_by!(name: @hospital_attr[:department])

      @candidate_attr = {
          data_source: 'excel', data_channel: 'excel', category2: 'doctor', created_by: @created_by, user_channel_id: @user_channel_id,
          first_name: first_name, last_name: last_name, expertise: expertise, city: "#{@hospital_attr[:province]} #{@hospital_attr[:city]}",
          inquiry: inquiry, cpt: cpt, currency: currency, property: { haodf_id: @haodf_id, haodf_url: haodf_url }
      }
      @work_exp_attrs << { org_id: @hospital.id, dep_id: @department.id, title: title, org_cn: @hospital.name, department: @department.name }
    end

  end
end