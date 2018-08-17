class ExchangeParticipant < ApplicationRecord
  before_save :encrypted_password

  validates :fullname, presence: true
  validates :cellphone, presence: true
  validates :email, presence: true,
                    uniqueness: true
  validates :birthdate, presence: true
  validates :password, presence: true

  belongs_to :registerable, polymorphic: true
  belongs_to :local_committee
  belongs_to :university
  belongs_to :college_course

  def decrypted_password
    return password if password_changed?
    password_encryptor.decrypt_and_verify(password)
  end

  def first_name
    fullname.split(' ').first
  end

  def last_name
    fullname.split(' ').drop(1).join(' ')
  end

  def as_sqs
    { exchange_participant_id: id }
  end

  private

  def encrypted_password
    self.password = password_encryptor.encrypt_and_sign(password)
  end

  def password_encryptor
    key = ActiveSupport::KeyGenerator.new('password')
                                     .generate_key(ENV['SALT'], 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
