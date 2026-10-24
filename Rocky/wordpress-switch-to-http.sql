update wp_options set option_value = Replace(option_value,'https://','http://') where option_name='siteurl' and option_value like 'https://%';
