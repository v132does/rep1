CREATE OR REPLACE FORCE VIEW IT.TA_BANK_CTA AS
SELECT to_number(substr(a.mensaje, 1, 10)) ctas,to_number(substr(mensaje, 46, 15)) id
FROM it.log_atm a WHERE to_number(substr(a.mensaje, 1, 10)) = '12140421'
and a.fec_insercion >='01/01/2019';

