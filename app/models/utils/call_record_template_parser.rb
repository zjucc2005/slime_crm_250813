# encoding: utf-8
module Utils
  class CallRecordTemplateParser
    # 解析通话记录导入模板

    attr_accessor :errors, :row, :created_by, :call_record_attr

    def initialize(row, created_by, project_id=nil)
      @row = row.map(&method(:cell_strip))
      @errors = []
      @created_by = created_by
      @project_id = project_id
      @call_record_attr = {}
      set_call_record_attr
    end

    # 返回值 true/false
    def import
      if valid?
        # import code
        begin
          CallRecord.create!(@call_record_attr)
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

    def set_call_record_attr
      name       = @row[0].to_s
      phone      = @row[1]
      company    = @row[2]
      department = @row[3]
      title      = @row[4]
      memo       = @row[5]

      # validates_presence_of - name, phone
      @errors << '姓名不能为空' if name.blank?
      # @errors << '电话不能为空' if phone.blank?
      @call_record_attr = {
        name: name, phone: phone, company: company, department: department, title: title, memo: memo, created_by: @created_by, project_id: @project_id
      }
    end

    private
    def cell_strip(cell)
      String === cell ? cell.strip : cell
    end
  end
end