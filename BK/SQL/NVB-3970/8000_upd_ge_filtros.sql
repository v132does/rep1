BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
UPDATE GE_FILTROS G
SET G.DET_SQL = 'Select ''Factura'' , ''F'' from dual
                 union
                 Select ''Orden de Pago'', ''O'' from dual
                 union
                 select ''Nota de Crédito'', ''N'' from dual'
WHERE G.COD_CAMPO = 'TIP_COMPRO';
