begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_tra_campos SET VAL_POSIBLES =
'select nvl(a.nro_documento,0) Boleta,  replace(nvl(b.denominacion,''_''),''~'',''N'') "Nombre de Cuenta", nvl(a.nro_cuenta,''_'') Cuenta, a.cod_moneda Moneda, ltrim(to_char(a.monto,''999,999,999,999.99'')) Monto
from ge_cuentas b,cj_movimientos a
where a.estado = ''N''
  and a.tip_monto in ( ''O'', ''T'', ''S'')
  and a.cod_tra_padre  in (215,395)
  and a.tipo = ''D''
 and a.nro_caja = '||'&'||'NRO_CAJA
  and b.nro_cuenta(+) = a.nro_cuenta
  and exists (select 0 from cj_cajas d
               where d.nro_caja = a.nro_caja
                 and d.tipo = ''A''
  )'
where cod_transaccion = 217 and cod_campo = 'NRO_BOLETA' ;

commit;
/
