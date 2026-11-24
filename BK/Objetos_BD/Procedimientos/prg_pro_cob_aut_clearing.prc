create or replace procedure it.PRG_PRO_COB_AUT_CLEARING  is
v_cod_error number;
v_mensaje varchar2(4000);

  cursor c_deudas is
   select c.fec_operacion,
          c.nro_cta_debito,
          c.beneficiario,
          c.nro_lote,
          c.tip_documento,
          c.nro_documento,
          c.cod_moneda,
          c.mto_tot_pend,
          c.estado,
          c.cod_ente
   from ge_deu_com_clientes c
   where c.estado!='P';
begin
 for reg in c_deudas loop
   
  PRG_DEB_AUT_DEU_CLEARING(reg.nro_cta_debito,
                           reg.fec_operacion, 
                           reg.nro_lote, 
                           reg.cod_ente,
                           v_cod_error,
                           v_mensaje);
 end loop;  
  commit;--se commitea una vez finalizado el proceso
  exception
    when others then
    prg_ins_log_programas('PRG_DEB_AUT_DEU_CLEARING',
                          substr('Ocurrio un error inesperado en el proceso de cobro automatico ' || ' ' ||
                                 DBMS_UTILITY.format_error_stack || ' - ' ||
                                 DBMS_UTILITY.format_error_backtrace,
                                 1,
                                 4000),
                          null,
                          null);
      
end PRG_PRO_COB_AUT_CLEARING;
/

