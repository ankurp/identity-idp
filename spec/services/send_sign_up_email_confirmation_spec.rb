require 'rails_helper'

describe SendSignUpEmailConfirmation do
  describe '#call' do
    let(:user) { create(:user, confirmed_at: nil) }
    let(:request_id) { '1234-abcd' }
    let(:instructions) { 'do the things' }
    let(:confirmation_token) { 'confirm-me' }

    before do
      allow(Devise).to receive(:friendly_token).once.and_return(confirmation_token)
      user.email_addresses.first.update!(
        confirmed_at: nil,
        confirmation_token: nil,
        confirmation_sent_at: nil,
      )
    end

    subject { described_class.new(user) }

    it 'sends the user an email with a confirmation link and the request id' do
      mail = double
      expect(mail).to receive(:deliver_later)
      expect(CustomDeviseMailer). to receive(:confirmation_instructions).with(
        user, confirmation_token, request_id: request_id, instructions: instructions
      ).and_return(mail)

      subject.call(request_id: request_id, instructions: instructions)
    end

    it 'creates updates the confirmation values on the email address for the user' do
      subject.call(request_id: request_id)

      expect(user.reload.email_addresses.count).to eq(1)
      email_address = user.email_addresses.first
      expect(email_address.email).to eq(user.email)
      expect(email_address.confirmation_token).to eq(confirmation_token)
      expect(email_address.confirmation_sent_at).to be_within(1.second).of(Time.zone.now)
      expect(email_address.confirmed_at).to eq(nil)
    end

    it 'updates the confirmation values on the user record' do
      subject.call(request_id: request_id)

      expect(user.confirmation_token).to eq(confirmation_token)
      expect(user.confirmation_sent_at).to be_within(1.second).of(Time.zone.now)
      expect(user.confirmed_at).to eq(nil)
    end

    context 'when the user already has a confirmation token' do
      it 'regenerates a token if the token is expired'

      it 'does not regenerate a token if the token is expired'
    end
  end
end