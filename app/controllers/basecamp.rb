def basecamp_api_call(basecamp_url)
	uri = URI(basecamp_url)

	response = ''
	Net::HTTP.start(uri.host, uri.port,
		:use_ssl => uri.scheme == 'https', 
		:verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

		request = Net::HTTP::Get.new uri.request_uri
		request.basic_auth 'danny.dorr@edentalmarket.com', 'JoshJosh1'

		response = http.request request # Net::HTTPResponse object
	end
	response.body
end