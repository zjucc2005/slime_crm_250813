# encoding: utf-8
class Doctor < Candidate
  # cancan 控制
  CATEGORY = { doctor: '医生', nurse: '护士', technician: '技师', pharmacist: '药师', other: '其他' }.stringify_keys

end