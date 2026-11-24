SELECT object_name, 
	   object_type,
	   status 
FROM all_objects 
WHERE status = 'INVALID' 
AND owner = 'IT';