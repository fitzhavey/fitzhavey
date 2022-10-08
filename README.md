### Hi there 👋
![programming gif](https://546kqu4mh4.execute-api.us-east-1.amazonaws.com/lambda_fitzhavey_readme-production/search?query=programmer)


#### How this works
A lambda returns a random programming related gif to be shown on my github page. This updates every few minutes as github's [camo](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-anonymized-urls) proxy is part of the site's rendering pipeline and provides some inescapable caching.

#### Terraform
The lambda, s3 bucket, api gateway, and related resources are configured in the `/terraform` directory.

#### Lambda
The lambda uses the giphy API with the search term "programmer" to return a random gif.
