module Idv
  class PhoneStep
    def initialize(idv_session:)
      self.idv_session = idv_session
    end

    def submit(step_params)
      self.step_params = step_params
      proof_address
    end

    def failure_reason
      return :fail if idv_session.step_attempts[:phone] >= idv_max_attempts
      return :timeout if idv_result[:timed_out]
      return :jobfail if idv_result[:exception].present?
      return :warning if idv_result[:success] != true
    end

    def async_state
      dcs_uuid = idv_session.idv_phone_step_document_capture_session_uuid
      dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
      return ProofingDocumentCaptureSessionResult.none if dcs_uuid.nil?
      return ProofingDocumentCaptureSessionResult.timed_out if dcs.nil?

      proofing_job_result = dcs.load_proofing_result
      return ProofingDocumentCaptureSessionResult.timed_out if proofing_job_result.nil?

      if proofing_job_result.result
        proofing_job_result.done
      elsif proofing_job_result.pii
        ProofingDocumentCaptureSessionResult.in_progress
      end
    end

    def async_state_done(async_state)
      @idv_result = async_state.result
      pii = async_state.pii

      increment_attempts_count unless failed_due_to_timeout_or_exception?
      success = idv_result[:success]
      handle_successful_proofing_attempt(pii) if success
      idv_session.idv_phone_step_document_capture_session_uuid = nil
      FormResponse.new(
        success: success, errors: idv_result[:errors],
        extra: extra_analytics_attributes
      )
    end

    private

    attr_accessor :idv_session, :step_params, :idv_result

    def idv_max_attempts
      Throttle::THROTTLE_CONFIG[:idv_resolution][:max_attempts]
    end

    def proof_address
      document_capture_session = DocumentCaptureSession.create(user_id: idv_session.current_user.id,
                                                               requested_at: Time.zone.now)

      document_capture_session.store_proofing_pii_from_doc(applicant)
      idv_session.idv_phone_step_document_capture_session_uuid = document_capture_session.uuid

      run_job(document_capture_session)
      add_proofing_cost
    end

    def handle_successful_proofing_attempt(successful_applicant)
      update_idv_session(successful_applicant)
      start_phone_confirmation_session(successful_applicant)
    end

    def add_proofing_cost
      Db::SpCost::AddSpCost.call(idv_session.issuer, 2, :lexis_nexis_address)
      Db::ProofingCost::AddUserProofingCost.call(idv_session.current_user.id, :lexis_nexis_address)
    end

    def applicant
      @applicant ||= idv_session.applicant.merge(
        phone: normalized_phone,
        uuid_prefix: uuid_prefix,
      )
    end

    def uuid_prefix
      ServiceProvider.from_issuer(idv_session.issuer).app_id
    end

    def normalized_phone
      @normalized_phone ||= begin
        formatted_phone = PhoneFormatter.format(phone_param)
        formatted_phone.gsub(/\D/, '')[1..-1] if formatted_phone.present?
      end
    end

    def phone_param
      step_phone = step_params[:phone]
      if step_phone == 'other'
        step_params[:other_phone]
      else
        step_phone
      end
    end

    def increment_attempts_count
      idv_session.step_attempts[:phone] += 1
    end

    def failed_due_to_timeout_or_exception?
      idv_result[:timed_out] || idv_result[:exception]
    end

    def update_idv_session(successful_applicant)
      idv_session.address_verification_mechanism = :phone
      idv_session.applicant = successful_applicant
      idv_session.vendor_phone_confirmation = true
      idv_session.user_phone_confirmation = phone_matches_user_phone?(successful_applicant[:phone])
      Db::ProofingComponent::Add.call(idv_session.current_user.id, :address_check,
                                      'lexis_nexis_address')
    end

    def start_phone_confirmation_session(successful_applicant)
      idv_session.user_phone_confirmation_session = PhoneConfirmation::ConfirmationSession.start(
        phone: PhoneFormatter.format(successful_applicant[:phone]),
        delivery_method: :sms,
      )
    end

    def phone_matches_user_phone?(phone)
      applicant_phone = PhoneFormatter.format(phone)
      return false if applicant_phone.blank?
      user_phones.include?(applicant_phone)
    end

    def user_phones
      MfaContext.new(
        idv_session.current_user,
      ).phone_configurations.map do |phone_configuration|
        PhoneFormatter.format(phone_configuration.phone)
      end.compact
    end

    def extra_analytics_attributes
      {
        vendor: idv_result.except(:errors, :success),
      }
    end

    def run_job(document_capture_session)
      Idv::Agent.new(applicant).proof_address(document_capture_session)
    end
  end
end
