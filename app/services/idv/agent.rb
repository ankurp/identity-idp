module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof_resolution(should_proof_state_id:)
      vendor = Idv::Proofer.resolution_vendor.new
      results = submit_applicant(vendor: vendor, results: init_results)

      return results unless results[:success] && should_proof_state_id

      vendor = Idv::Proofer.state_id_vendor.new
      submit_applicant(vendor: vendor, results: results)
    end

    def proof_address(document_capture_session)
      callback_url = Rails.application.routes.url_helpers.address_proof_result_url(
        document_capture_session.result_id,
      )

      LambdaJobs::Runner.new(
        job_name: nil, job_class: Idv::Proofer.address_job_class,
        args: { applicant_pii: @applicant, callback_url: callback_url }
      ).run do |idv_result|
        document_capture_session.store_proofing_result(idv_result[:address_result])

        nil
      end
    end

    private

    def init_results
      {
        errors: {},
        messages: [],
        context: {
          stages: [],
        },
        exception: nil,
        success: false,
        timed_out: false,
      }
    end

    def submit_applicant(vendor:, results:)
      log_vendor(vendor, results, vendor.class.stage)
      proofer_result = vendor.proof(@applicant)

      track_exception_in_result(proofer_result)
      results = merge_results(results, proofer_result)
      results[:timed_out] = proofer_result.timed_out?

      results
    end

    def log_vendor(vendor, results, stage)
      v_class = vendor.class
      results[:context][:stages].push(stage => v_class.vendor_name || v_class.inspect)
    end

    def merge_results(results, proofer_result)
      results.merge(proofer_result.to_h) do |key, orig, current|
        key == :messages ? orig + current : current
      end
    end

    def track_exception_in_result(proofer_result)
      exception = proofer_result.exception
      return if exception.nil?

      NewRelic::Agent.notice_error(exception)
      ExceptionNotifier.notify_exception(exception)
    end
  end
end
