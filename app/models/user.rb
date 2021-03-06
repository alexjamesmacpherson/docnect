class User < ApplicationRecord
  has_many :doctors, :class_name => 'Appointment', :foreign_key => 'doctor_id', dependent: :destroy
  has_many :patients, :class_name => 'Appointment', :foreign_key => 'patient_id', dependent: :destroy

  # Remove whitespace
  auto_strip_attributes :email, :name, :specialization, :phone, :occupation, :nationality, :languages, :squish => true
  auto_strip_attributes :address, :bio, :hobbies, :allergies, :smoke, :alcohol, :tattoos, :history, :medication, :illness

  # Attribute accessors
  attr_accessor :remember_token, :activation_token, :reset_token

  # Downcase email address before saving the user
  before_save :downcase_email
  before_save :titlize_name
  before_save :cleanse_address
  before_create :create_activation_digest

  # Global user record validation
  VALID_EMAIL_REGEX = /\A([\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+)?\z/i
  validates :email,
            presence: true,
            length: { maximum: 255 },
            format: { with: VALID_EMAIL_REGEX },
            uniqueness: {case_sensitive: false }
  # User groups: 0=super user, 1=patient, 2=doctor
  validates :user_group,
            presence: true,
            inclusion: 0..2
  validates :name,
            presence: true,
            length: { maximum: 255 }
  has_secure_password
  validates :password,
            presence: true,
            length: { minimum: 6 },
            allow_nil: true

  # Doctor-specific record validation
  validates :specialization,
            presence: true,
            length: { maximum: 255 },
            if: :is_doctor?
  # Regular expression matches numbers of form XXXXX XXXXXX | (+XX?X?)? (X)? XXXX XXXXXX - brackets, hyphens, slashes and spaces optional
  # Weak validation - basically ensures roughly correct length and only valid character entry
  VALID_PHONE_NUMBER_REGEX = /\A(([ \-()\/]?\d[ \-()\/]?){11}|([ \-()\/]?\+[ \-()\/]?)([ \-()\/]?\d[ \-()\/]?){1,3}([ ])?([ \-()\/]?\d[ \-()\/]?){10,11})\z/i
  validates :phone,
            presence: true,
            format: { with: VALID_PHONE_NUMBER_REGEX },
            if: :is_doctor?
  validates :address,
            presence: true,
            if: :is_doctor?
  validates :bio,
            presence: true,
            allow_blank: true,
            if: :is_doctor?

  # Patient-specific record validation
  validates :dob, :nationality, :hobbies, :languages, :height, :weight, :allergies, :smoke, :alcohol, :tattoos, :history, :medication, :illness,
            presence: true,
            if: :is_patient?
  validates :occupation, :marital_status,
            presence: true,
            length: { maximum: 255 },
            if: :is_patient?
  validates :drugs,
            inclusion: { in: [ true, false ] },
            if: :is_patient?

  # Methods defined here are of form User.foo()
  class << self
    # Returns hashed digest of given string, used by user fixtures for tests
    def digest(string)
      cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
      BCrypt::Password.create(string, cost: cost)
    end

    # Generate and return a new random token
    def new_token
      SecureRandom.urlsafe_base64
    end
  end

  # Generate and set persistent session (remember) token
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  # Forget persistent session (remember) token
  def forget
    update_attribute(:remember_digest, nil)
  end

  # Checks remember digest against given remember token (from cookie), true if match, false otherwise (catches nil token case)
  def authenticated?(attribute, token)
    digest = send("#{attribute}_digest")
    return false if digest.nil?
    BCrypt::Password.new(digest).is_password?(token)
  end

  def activate
    update_columns(activated: true, activated_at: Time.zone.now)
  end

  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end

  def create_reset_digest
    self.reset_token = User.new_token
    update_columns(reset_digest: User.digest(reset_token), reset_sent_at: Time.zone.now)
  end

  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end

  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  def send_new_patient_email(patient)
    UserMailer.new_patient(self, patient).deliver_now
  end

  # Returns true if user has given user group
  def group?(group)
    user_group == group
  end

private

  def downcase_email
    email.downcase!
  end

  def titlize_name
    self.name = name.titleize
  end

  def cleanse_address
    if address && is_doctor?
      addr = ''
      address.each_line do |line|
        unless line.blank?
          line.gsub!(/(^[ ]+)|([ ]+$)/, '')
          line.gsub!(/([ ]*\r$)/, "\r")
          if /,\r$/.match(line)
            addr += line.gsub(/(^[ ]+)|([ ]+$)/, '').gsub(/([ ]*,\r$)/, ",\r")
          else
            addr += line.gsub(/(^[ ]+)/, '').gsub(/[ ]*\r/, ",\r")
          end
        end
      end
      self.address = addr
    end
  end

  def is_doctor?
    activated && group?(2) && !reset_digest
  end

  def is_patient?
    activated && group?(1) && !reset_digest
  end

  def create_activation_digest
    self.activation_token = User.new_token
    self.activation_digest = User.digest(activation_token)
  end
end
