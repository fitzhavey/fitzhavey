const axios = require('axios');

function randomIntFromInterval(min, max) { // min and max included
	return Math.floor(Math.random() * (max - min + 1) + min)
  }

module.exports.handler = async (event) => {
	console.log('Event: ', event);

	const GIPHY_API_KEY = process.env.GIPHY_API_KEY;
	let searchTerm = '';

	if (event.queryStringParameters && event.queryStringParameters['query']) {
		searchTerm = event.queryStringParameters['query'];
	}

	const offset = randomIntFromInterval(0, 13);
	const requestUrl = `https://api.giphy.com/v1/gifs/search?api_key=${GIPHY_API_KEY}&q=${searchTerm}&limit=1&offset=${offset}&rating=g&lang=en`
	const response = await axios.get(requestUrl);

	const gifUrl = response.data.data[0].images.original.url;

	const imageBase64 = await axios
		.get(gifUrl, { responseType: 'arraybuffer' })
		.then((response) => Buffer.from(response.data, 'binary').toString('base64'));


	return {
		statusCode: 200,
		isBase64Encoded: true,
		headers: {
			'Content-Type': 'image/gif',
			'Cache-Control': 'no-store'
		},
		body: imageBase64
	}
}