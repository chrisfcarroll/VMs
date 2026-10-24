update wp_options set option_value = Replace(option_value,'http://','https://') where option_name='siteurl' and option_value like 'http://%';
