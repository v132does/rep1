CREATE OR REPLACE FORCE VIEW IT.GV_MAD_MONEDAS AS
SELECT distinct cod_modulo, cod_modalidad, cod_moneda
from cr_piz_montos;

