BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
/
update IT.ba_consultas con
set con.det_sql=
'SELECT to_char(a.fec_envio,''dd/mm/yyyy'') Fecha_Envio,
                    a.cod_moneda Moneda,
                    a.cod_banco Cod_Bco,
                    FUG_OBT_DES_BANCO(a.cod_banco)  Nombre_bco,
                    a.cta_libradora Cta_Libradora,
                    a.nro_cuenta Cuenta,
                    a.nro_cheque Cheque,
                    a.monto Monto,
                    a.cod_ofi_compensacion Ofi_Comp,
                    a.cod_ofi_origen Ofi_Orig,
                    a.nro_caja Nro_Caja
                    FROM CC_CHE_ENVIADOS a
                    where ('||'&'||'P_FILTROS)'
where con.cod_consulta='RPCHEREM';
/
--filtro
update ba_par_consultas a
 set a.val_defecto='Igual_a ''05/01/2024'''
 where a.cod_consulta= 'RPCHEREM'
 and a.cod_campo='FEC_ENCHE'
 and a.nro_orden= 4;
/
commit;


