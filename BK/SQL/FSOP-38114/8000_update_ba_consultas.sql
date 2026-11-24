begin
  pre_ini_aplicacion;pae_cnf.g_cod_modulo := 1;
end;
/ 
update ba_consultas s 
set s.det_sql = 'select t.MT_Campos MT_Campos,
       t.Fecha Fecha,
       t.moneda Moneda,
       t.Tipo Tipo,
       t.Importe Importe,
       t.Referencia_BCP Referencia_BCP,
       t.Tipo_MT Tipo_MT,
       t.Referencia Referencia,
       t.Ref_Consolidada Ref_Consolidada,
       t.Plataforma Plataforma,
       t.Estado Estado,
       t.Nro_Ref_Rev_Recibida Nro_Ref_Rev_Recibida,
       t.Nro_Ref_Rev_Enviada Nro_Ref_Rev_Enviada,
       t.Sal_ini Saldo_Inical,
       t.sal_fin Saldo_Final
from SV_CON_SIPAP t
where (' || '&' || 'P_FILTROS'||')'
where s.cod_consulta = 'CD_CON_SIP';

commit;
