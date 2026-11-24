begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;END;
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, TIPO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_CEF_LEG', 'Extracto de Cuentas - Legales', 'P', null, 'SELECT c.denominacion "Denominación",
       a.NRO_CUENTA "Nro. Cuenta",
       to_char(a.FECHA,''dd/mm/yyyy'') "Fecha",
       to_char(a.FEC_VALOR,''dd/mm/yyyy'') "Fec. Valor",
       a.HORA "Hora",
       a.NRO_DOCUMENTO "Nro. Documento",
       a.CONCEPTO "Concepto",
       (DECODE(b.cod_transaccion,
               515,
               0,
               560,
               0,
               decode(b.TIPO, ''D'', NVL(a.MONTO, 0), 0))) "Débito",
       (DECODE(b.cod_transaccion,
               515,
               NVL(a.MONTO, 0),
               560,
               NVL(a.MONTO, 0),
               decode(b.TIPO, ''C'', NVL(a.MONTO, 0), 0))) "Crédito"
  FROM ge_transacciones b, gv_movimientos a, ah_cta_vistas c
 WHERE c.nro_cuenta = a.NRO_CUENTA
   AND a.ESTADO = ''N''
   AND a.reversado = ''N''
   AND a.COD_MODULO = b.COD_MODULO
   AND a.COD_MODALIDAD = b.COD_MODALIDAD
   AND a.COD_TRANSACCION = b.COD_TRANSACCION
   AND b.VE_CLIENTE = ''S''
   AND b.TIPO IN (''C'', ''D'')
   AND NOT EXISTS (SELECT 1 FROM ge_cta_clientes gc, ge_clientes g 
                   where gc.cod_persona = g.cod_persona 
                   and gc.nro_cuenta = c.nro_cuenta 
                   and g.cod_seg_cliente = fug_obt_pardinamico(''SEG_FUNCIONARIOS''))
   AND (&'||'P_FILTROS)', null, '1,2', null);

commit;
