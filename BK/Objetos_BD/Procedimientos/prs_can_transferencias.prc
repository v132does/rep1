create or replace procedure it.prs_can_transferencias is
g_fec_actual date   := pag_cal.fu_obt_fec_actual(1);
--cancelar transferencias por connection closed, que no tengan movimiento generado
cursor transfer is
     select t.nro_referencia from ge_snp_transferencias t
      where t.fec_recepcion is  null
      and t.fec_valor<=g_fec_actual
      and t.estado='S'
      and t.situacion='P'
      and t.usu_insercion not in ('HBANKJ','TRAEXPERIE')
      and t.fecha is null
      and t.hora is null
      and t.cod_usuario is null
      and ((sysdate) -t.fec_insercion)*24*60 >5--pasado ya 5 minutos de insercion
      order by t.fec_insercion desc;
begin
  begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   for x in transfer loop
        update ge_snp_transferencias
        set situacion='C', estado='C'
        where nro_referencia = x.nro_referencia;
         commit;
    end loop;

end prs_can_transferencias;
/
