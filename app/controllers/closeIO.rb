def closeio_api_call(closeio_url)
	uri = URI(closeio_url)

	response = ''
	Net::HTTP.start(uri.host, uri.port,
		:use_ssl => uri.scheme == 'https', 
		:verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

		request = Net::HTTP::Get.new uri.request_uri
		request.basic_auth '18504bd03ed58953928ad3e8c18b505ecb2f6f6e9051510e99eea6cf', ''

		response = http.request request # Net::HTTPResponse object
	end
	response.body
end