module Utils
  class ExcelDropdown
    class << self
      def interviewee_type_list
        '临床科室普通医生,临床科室科（副）主任,非临床科室普通技师/科员,非临床科室科（副）主任,医院行政管理层,KOL（省市级）,KOL（国家级）,护士,护士长,患者（非肿瘤常见病）,患者（肿瘤及罕见病）,患者家属（非肿瘤常见病）,患者家属（肿瘤及罕见病）,患者组织/医疗平台负责人,制药/器械厂家（经理级）,制药/器械厂家（总监级及以上）,学术专家/学者（省市级）,学术专家/学者（国家级）,药店店长,药店店员,普通消费者,特殊消费者,其他，请注明'.split(',')
      end

      def fw_method_list
        '定性IDI（面对面访问）,定性IDI（电话访问）,定性FGD（线下座谈会/专家研讨会）,定性FGD（线上座谈会/专家研讨会）,定量F2F（线下面对面访问）,定量CATI,定量Online（3rd-Party）,定量Online（IQVIA WeChat）,定量Retail查店,其他，请注明'.split(',')
      end

      def hospital_level_list
        '三级,二级,一级,未评级'.split(',')
      end

      def jishuzhicheng_list
        '住院医师,主治医师,副主任医师,主任医师'.split(',')
      end

      def xingzhengzhiwu_list
        '科主任,科副主任'.split(',')
      end

      def lijin_payer_list
        'IQVIA平台支付（研究生成二维码）,IQVIA平台支付（代理生成二维码）,由代理支付礼金'.split(',')
      end

      def lijin_payment_list
        '现金,银行卡转账（公对私）,支付宝转账（公对私）,支付宝转账（私对私）,微信转账（公对私）,微信转账（私对私）,积分,其他，请注明'.split(',')
      end

    end
  end
end