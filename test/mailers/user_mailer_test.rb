require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'account activation' do
    user = users(:patient)
    user.activation_token = User.new_token
    mail = UserMailer.account_activation(user)

    assert_equal 'Activate Your Docnect Account!', mail.subject
    assert_equal [user.email], mail.to
    assert_equal ['noreply@docnect.herokuapp.com'], mail.from

    assert_match user.name, mail.body.encoded
    assert_match user.activation_token, mail.body.encoded
    assert_match CGI.escape(user.email), mail.body.encoded
  end

  test 'password reset' do
    user = users(:patient)
    user.reset_token = User.new_token
    mail = UserMailer.password_reset(user)

    assert_equal 'Reset Your Password', mail.subject
    assert_equal [user.email], mail.to
    assert_equal ['noreply@docnect.herokuapp.com'], mail.from

    assert_match user.name, mail.body.encoded
    assert_match user.reset_token, mail.body.encoded
    assert_match CGI.escape(user.email), mail.body.encoded
  end
end
